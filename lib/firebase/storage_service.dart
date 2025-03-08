import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile, String fileName) async {
    try {
      // Compress image
      File compressedFile = await _compressImage(imageFile);

      // Upload to Firebase Storage
      Reference ref = _storage.ref().child('profiles/$fileName');
      UploadTask uploadTask = ref.putFile(compressedFile);
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload post image
  Future<String> uploadPostImage(File imageFile) async {
    try {
      String postId = _uuid.v4();

      // Compress image
      File compressedFile = await _compressImage(imageFile);

      // Upload to Firebase Storage
      Reference ref = _storage.ref().child('posts/images/$postId');
      UploadTask uploadTask = ref.putFile(compressedFile);
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload post video
  Future<String> uploadPostVideo(File videoFile) async {
    try {
      String postId = _uuid.v4();

      // Compress video
      MediaInfo? compressedInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (compressedInfo?.file == null) {
        throw Exception('Failed to compress video');
      }

      // Upload to Firebase Storage
      Reference ref = _storage.ref().child('posts/videos/$postId');
      UploadTask uploadTask = ref.putFile(compressedInfo!.file!);
      TaskSnapshot snapshot = await uploadTask;

      // Generate thumbnail as well
      File? thumbnailFile = await _generateVideoThumbnail(videoFile);
      if (thumbnailFile != null) {
        Reference thumbRef = _storage.ref().child('posts/thumbnails/$postId');
        await thumbRef.putFile(thumbnailFile);
      }

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload chat image
  Future<String> uploadChatImage(File imageFile) async {
    try {
      String messageId = _uuid.v4();

      // Compress image
      File compressedFile = await _compressImage(imageFile);

      // Upload to Firebase Storage
      Reference ref = _storage.ref().child('chats/images/$messageId');
      UploadTask uploadTask = ref.putFile(compressedFile);
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Compress image helper method
  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final targetPath = '$path/${DateTime.now().millisecondsSinceEpoch}.jpg';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // Adjust quality as needed
    );

    if (result == null) {
      print("Image compression failed, using original file");
      return file;
    }

    return File(result.path);
  }

  // Generate video thumbnail
  Future<File?> _generateVideoThumbnail(File videoFile) async {
    try {
      final thumbnail = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: 50,
      );
      return thumbnail;
    } catch (e) {
      return null;
    }
  }

  // Delete media from storage
  Future<void> deleteMedia(String mediaUrl) async {
    try {
      // Extract reference path from URL
      Reference ref = _storage.refFromURL(mediaUrl);
      await ref.delete();
    } catch (e) {
      // Silently fail if file doesn't exist
    }
  }
}