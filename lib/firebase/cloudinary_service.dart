import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final cloudinary = CloudinaryPublic('ds8ap1c3l', 'pu_circle_posts', cache: false);
  final Uuid _uuid = const Uuid();

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile, String fileName) async {
    return _uploadWithRetry(() async {
      print("DEBUG: Starting profile image upload for $fileName");

      // Compress image
      File compressedFile = await _compressImage(imageFile);
      print("DEBUG: Image compressed successfully");

      // Upload to Cloudinary
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          compressedFile.path,
          folder: 'profiles',
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      print("DEBUG: Profile image uploaded successfully. URL: ${response.secureUrl}");
      return response.secureUrl;
    });
  }

  // Upload post image
  Future<String> uploadPostImage(File imageFile, {String? fileName}) async {
    return _uploadWithRetry(() async {
      print("DEBUG: Starting post image upload");
      String postId = fileName ?? _uuid.v4();
      print("DEBUG: Using post ID: $postId");

      // Compress image
      File compressedFile = await _compressImage(imageFile);
      print("DEBUG: Image compressed successfully. Size: ${compressedFile.lengthSync()}");

      // Upload to Cloudinary
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          compressedFile.path,
          folder: 'posts/images',
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      String downloadUrl = response.secureUrl;
      print("DEBUG: Post image uploaded successfully. URL: $downloadUrl");

      return downloadUrl;
    });
  }

  // Upload post video
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

      // Upload to Cloudinary
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          compressedFile.path,
          folder: 'posts/videos',
          resourceType: CloudinaryResourceType.Video,
        ),
      );

      String downloadUrl = response.secureUrl;

      // Generate and upload thumbnail
      try {
        print("DEBUG: Generating video thumbnail");
        File? thumbnailFile = await _generateVideoThumbnail(compressedFile);
        if (thumbnailFile != null) {
          await cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              thumbnailFile.path,
              folder: 'posts/thumbnails',
              resourceType: CloudinaryResourceType.Image,
            ),
          );
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

  // Upload chat image
  Future<String> uploadChatImage(File imageFile) async {
    return _uploadWithRetry(() async {
      String messageId = _uuid.v4();
      print("DEBUG: Starting chat image upload with ID: $messageId");

      // Compress image
      File compressedFile = await _compressImage(imageFile);
      print("DEBUG: Chat image compressed successfully");

      // Upload to Cloudinary
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          compressedFile.path,
          folder: 'chats/images',
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      String downloadUrl = response.secureUrl;
      print("DEBUG: Chat image uploaded successfully. URL: $downloadUrl");

      return downloadUrl;
    });
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

        // Wait before retrying - exponential backoff
        int delayMs = 1000 * (2 << (attempts - 1)); // 2s, 4s, 8s...
        print("INFO: Retrying in ${delayMs}ms...");
        await Future.delayed(Duration(milliseconds: delayMs));

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

  // Delete media from Cloudinary
  Future<void> deleteMedia(String mediaUrl) async {
    if (mediaUrl.isEmpty) {
      print("WARNING: Empty URL provided for deletion");
      return;
    }

    // Note: Cloudinary requires API credentials to delete resources
    // This function would typically be handled by a server-side function
    // as it requires your API Secret (which shouldn't be in client-side code)

    // For PU Circle, you'd need to implement this on your backend
    // For now, we'll just log the request
    print("DEBUG: Media deletion requested for URL: $mediaUrl");
    print("NOTE: Cloudinary media deletion requires server-side implementation");

    // Return success as if deletion occurred
    // In a production app, you would want to implement proper deletion via a backend service
  }
}