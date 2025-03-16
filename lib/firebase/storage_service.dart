import 'dart:io';
import 'dart:typed_data';  // Correct import for Uint8List
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Initialize storage paths
  Future<void> _ensureStoragePaths() async {
    print("DEBUG: Ensuring storage paths exist");
    try {
      // Create placeholder files in each directory to ensure they exist
      final paths = [
        'posts/images/.placeholder',
        'posts/videos/.placeholder',
        'posts/thumbnails/.placeholder',
        'profiles/.placeholder',
        'chats/images/.placeholder'
      ];

      for (String path in paths) {
        try {
          final ref = _storage.ref().child(path);
          // Check if placeholder exists
          try {
            await ref.getDownloadURL();
            print("DEBUG: Path exists: $path");
          } catch (e) {
            // Create placeholder if it doesn't exist
            final emptyData = Uint8List.fromList([0]); // Create a single-byte placeholder
            await ref.putData(emptyData, SettableMetadata(contentType: 'application/octet-stream'));
            print("DEBUG: Created placeholder for path: $path");
          }
        } catch (e) {
          print("WARNING: Failed to ensure path exists: $path - $e");
        }
      }
    } catch (e) {
      print("WARNING: Failed to ensure storage paths: $e");
    }
  }

  // Upload profile image with retry mechanism
  Future<String> uploadProfileImage(File imageFile, String fileName) async {
    return _uploadWithRetry(() async {
      print("DEBUG: Starting profile image upload for $fileName");

      // Compress image
      File compressedFile = await _compressImage(imageFile);
      print("DEBUG: Image compressed successfully");

      // Upload to Firebase Storage
      Reference ref = _storage.ref().child('profiles/$fileName.jpg');
      final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'fileName': '$fileName.jpg'}
      );

      TaskSnapshot snapshot = await _uploadFile(compressedFile, ref, metadata);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("DEBUG: Profile image uploaded successfully. URL: $downloadUrl");

      return downloadUrl;
    });
  }

  // Upload post image with retry mechanism
  Future<String> uploadPostImage(File imageFile, {String? fileName}) async {
    // Ensure storage paths exist first
    await _ensureStoragePaths();
    
    return _uploadWithRetry(() async {
      print("DEBUG: Starting post image upload");
      String postId = fileName ?? _uuid.v4();
      print("DEBUG: Using post ID: $postId");

      // Compress image
      File compressedFile = await _compressImage(imageFile);
      print("DEBUG: Image compressed successfully. Size: ${compressedFile.lengthSync()}");

      // Upload to Firebase Storage with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'fileName': '$postId.jpg'}
      );

      // Using a more direct path structure
      Reference ref = _storage.ref().child('posts/images/$postId.jpg');
      print("DEBUG: Uploading to path: ${ref.fullPath}");

      // Verify the path exists
      try {
        await ref.parent?.getDownloadURL();
      } catch (e) {
        print("DEBUG: Creating directory structure for: ${ref.fullPath}");
        await _ensureStoragePaths();
      }

      TaskSnapshot snapshot = await _uploadFile(compressedFile, ref, metadata);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("DEBUG: Post image uploaded successfully. URL: $downloadUrl");

      return downloadUrl;
    });
  }

  // Upload post video with retry mechanism
  Future<String> uploadPostVideo(File videoFile, {String? fileName}) async {
    return _uploadWithRetry(() async {
      print("DEBUG: Starting post video upload");
      String postId = fileName ?? _uuid.v4();
      print("DEBUG: Using post ID: $postId");

      // Compress video
      print("DEBUG: Starting video compression");
      File? compressedFile;

      try {
        MediaInfo? compressedInfo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (compressedInfo?.file == null) {
          print("WARNING: Video compression failed, using original file");
          compressedFile = videoFile;
        } else {
          compressedFile = compressedInfo!.file!;
          print("DEBUG: Video compressed successfully. Original: ${videoFile.lengthSync()}, Compressed: ${compressedFile.lengthSync()}");
        }
      } catch (e) {
        print("WARNING: Error during video compression: $e");
        compressedFile = videoFile; // Fallback to original
      }

      // Upload to Firebase Storage
      final metadata = SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {'fileName': '$postId.mp4'}
      );

      Reference ref = _storage.ref().child('posts/videos/$postId.mp4');
      print("DEBUG: Uploading video to path: ${ref.fullPath}");

      TaskSnapshot snapshot = await _uploadFile(compressedFile, ref, metadata);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Generate and upload thumbnail
      try {
        print("DEBUG: Generating video thumbnail");
        File? thumbnailFile = await _generateVideoThumbnail(videoFile);
        if (thumbnailFile != null) {
          Reference thumbRef = _storage.ref().child('posts/thumbnails/$postId.jpg');
          await _uploadFile(thumbnailFile, thumbRef, SettableMetadata(contentType: 'image/jpeg'));
          print("DEBUG: Thumbnail uploaded successfully");
        } else {
          print("WARNING: Failed to generate thumbnail");
        }
      } catch (e) {
        print("WARNING: Error generating thumbnail: $e");
        // Continue even if thumbnail fails
      }

      print("DEBUG: Video uploaded successfully. URL: $downloadUrl");
      return downloadUrl;
    });
  }

  // Upload chat image with retry mechanism
  Future<String> uploadChatImage(File imageFile) async {
    return _uploadWithRetry(() async {
      String messageId = _uuid.v4();
      print("DEBUG: Starting chat image upload with ID: $messageId");

      // Compress image
      File compressedFile = await _compressImage(imageFile);
      print("DEBUG: Chat image compressed successfully");

      // Upload to Firebase Storage
      Reference ref = _storage.ref().child('chats/images/$messageId.jpg');
      final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'messageId': messageId}
      );

      TaskSnapshot snapshot = await _uploadFile(compressedFile, ref, metadata);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("DEBUG: Chat image uploaded successfully. URL: $downloadUrl");

      return downloadUrl;
    });
  }

  // Centralized upload function with progress monitoring
  Future<TaskSnapshot> _uploadFile(File file, Reference ref, SettableMetadata metadata) async {
    // Verify file exists and is readable
    if (!file.existsSync()) {
      throw Exception("File does not exist: ${file.path}");
    }

    UploadTask uploadTask = ref.putFile(file, metadata);

    // Monitor upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
      print('DEBUG: Upload progress for ${ref.fullPath}: ${progress.toStringAsFixed(2)}%');
    }, onError: (error) {
      print("ERROR: Upload progress monitoring error for ${ref.fullPath}: $error");
    }, cancelOnError: false);

    try {
      TaskSnapshot snapshot = await uploadTask;
      print("DEBUG: Upload completed successfully for ${ref.fullPath}");
      return snapshot;
    } catch (e) {
      print("ERROR: File upload failed for path ${ref.fullPath}: $e");
      if (e is FirebaseException) {
        print("ERROR: Firebase error code: ${e.code}");
        print("ERROR: Firebase error message: ${e.message}");
      }
      rethrow;
    }
  }

  // Retry mechanism for uploads
  Future<T> _uploadWithRetry<T>(Future<T> Function() uploadFunction, {int maxRetries = 3}) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await uploadFunction();
      } catch (e) {
        attempts++;
        print("ERROR: Upload attempt $attempts failed: $e");

        if (e is FirebaseException) {
          print("ERROR: Firebase error code: ${e.code}");
          print("ERROR: Firebase error message: ${e.message}");

          // Check if we should retry based on error type
          if (e.code == 'object-not-found' ||
              e.code == 'unauthorized' ||
              e.code == 'app-check-token-expired' ||
              e.code == 'quota-exceeded') {

            if (attempts >= maxRetries) {
              print("ERROR: Max retry attempts reached for error: ${e.code}");
              rethrow;
            }

            // Wait before retrying - exponential backoff
            int delayMs = 1000 * (2 << (attempts - 1)); // 2s, 4s, 8s...
            print("INFO: Retrying in ${delayMs}ms...");
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
        }

        // For any other errors or if we've reached max retries
        if (attempts >= maxRetries) {
          print("ERROR: Max retry attempts reached");
          rethrow;
        }
      }
    }

    // This should never happen, but Dart requires a return statement
    throw Exception("Unexpected error in retry mechanism");
  }

  // Compress image helper method
  Future<File> _compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Check file size to determine compression quality
      int fileSize = file.lengthSync();
      int quality = 80; // Default quality

      // Adjust quality based on file size
      if (fileSize > 5 * 1024 * 1024) { // > 5MB
        quality = 60;
      } else if (fileSize > 2 * 1024 * 1024) { // > 2MB
        quality = 70;
      }

      print("DEBUG: Compressing image with quality: $quality");

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        print("WARNING: Image compression failed, using original file");
        return file;
      }

      File compressedFile = File(result.path);
      print("DEBUG: Image compressed successfully. Original: ${file.lengthSync()}, Compressed: ${compressedFile.lengthSync()} bytes");

      // If compression didn't help much, use original
      if (compressedFile.lengthSync() > file.lengthSync() * 0.9) {
        print("DEBUG: Compression ineffective, using original file");
        return file;
      }

      return compressedFile;
    } catch (e) {
      print("ERROR: Image compression failed: $e");
      return file; // Return original on error
    }
  }

  // Generate video thumbnail
  Future<File?> _generateVideoThumbnail(File videoFile) async {
    try {
      final thumbnail = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: 50,
        position: -1, // Auto-select good frame
      );
      print("DEBUG: Thumbnail generated successfully");
      return thumbnail;
    } catch (e) {
      print("ERROR: Thumbnail generation failed: $e");
      return null;
    }
  }

  // Delete media from storage
  Future<void> deleteMedia(String mediaUrl) async {
    if (mediaUrl.isEmpty) {
      print("WARNING: Empty URL provided for deletion");
      return;
    }

    try {
      print("DEBUG: Attempting to delete media at URL: $mediaUrl");
      Reference ref = _storage.refFromURL(mediaUrl);
      await ref.delete();
      print("DEBUG: Media deleted successfully from path: ${ref.fullPath}");

      // Try to delete thumbnail if it's a video
      if (ref.fullPath.contains('posts/videos/')) {
        String fileName = ref.name;
        String fileNameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

        try {
          Reference thumbRef = _storage.ref().child('posts/thumbnails/$fileNameWithoutExt.jpg');
          await thumbRef.delete();
          print("DEBUG: Associated thumbnail also deleted");
        } catch (e) {
          // Thumbnail might not exist, ignore error
          print("DEBUG: No associated thumbnail found or couldn't be deleted");
        }
      }
    } catch (e) {
      print("ERROR: Failed to delete media: $e");
      if (e is FirebaseException) {
        print("ERROR: Firebase error code: ${e.code}");
        // If file doesn't exist (object-not-found), treat as success
        if (e.code == 'object-not-found') {
          print("INFO: Object already deleted or doesn't exist");
          return;
        }
      }
      // For other errors, rethrow
      rethrow;
    }
  }
}