// lib/services/supabase_storage_service.dart
// Replaces Cloudinary — uses Supabase Storage for all image/video uploads.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _imagesBucket = 'property-images';
  static const String _videosBucket = 'property-videos';
  static const _uuid = Uuid();

  // ── Upload single image ───────────────────────────────────────────────────
  Future<String?> uploadImage(File file, {String folder = 'properties'}) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '$folder/${_uuid.v4()}.$ext';

      await _supabase.storage.from(_imagesBucket).upload(
            fileName,
            file,
            fileOptions: FileOptions(
              contentType: _imageMimeType(ext),
              upsert: false,
            ),
          );

      final url =
          _supabase.storage.from(_imagesBucket).getPublicUrl(fileName);
      if (kDebugMode) print('✅ Image uploaded: $url');
      return url;
    } catch (e) {
      if (kDebugMode) print('❌ Error uploading image: $e');
      return null;
    }
  }

  // ── Upload single video ───────────────────────────────────────────────────
  Future<String?> uploadVideo(File file, {String folder = 'properties'}) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '$folder/${_uuid.v4()}.$ext';

      await _supabase.storage.from(_videosBucket).upload(
            fileName,
            file,
            fileOptions: FileOptions(
              contentType: _videoMimeType(ext),
              upsert: false,
            ),
          );

      final url =
          _supabase.storage.from(_videosBucket).getPublicUrl(fileName);
      if (kDebugMode) print('✅ Video uploaded: $url');
      return url;
    } catch (e) {
      if (kDebugMode) print('❌ Error uploading video: $e');
      return null;
    }
  }

  // ── Upload multiple images ────────────────────────────────────────────────
  Future<List<String>> uploadImages(List<File> images,
      {String folder = 'properties'}) async {
    final urls = <String>[];
    for (int i = 0; i < images.length; i++) {
      if (kDebugMode) {
        print('⏳ Uploading image ${i + 1}/${images.length}...');
      }
      final url = await uploadImage(images[i], folder: folder);
      if (url != null) urls.add(url);
    }
    if (kDebugMode) {
      print('📸 Uploaded ${urls.length}/${images.length} images');
    }
    return urls;
  }

  // ── Upload multiple videos ────────────────────────────────────────────────
  Future<List<String>> uploadVideos(List<File> videos,
      {String folder = 'properties'}) async {
    final urls = <String>[];
    for (int i = 0; i < videos.length; i++) {
      if (kDebugMode) {
        print('⏳ Uploading video ${i + 1}/${videos.length}...');
      }
      final url = await uploadVideo(videos[i], folder: folder);
      if (url != null) urls.add(url);
    }
    if (kDebugMode) {
      print('📹 Uploaded ${urls.length}/${videos.length} videos');
    }
    return urls;
  }

  // ── Delete a file by its public URL ──────────────────────────────────────
  Future<bool> deleteFile(String publicUrl) async {
    try {
      // Extract the path from the public URL.
      // Supabase public URLs look like:
      // https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
      final uri = Uri.parse(publicUrl);
      final segments = uri.pathSegments;
      // segments: ['storage', 'v1', 'object', 'public', bucketName, ...path]
      final bucketIndex = segments.indexOf('public');
      if (bucketIndex == -1 || bucketIndex + 2 >= segments.length) {
        return false;
      }

      final bucket = segments[bucketIndex + 1];
      final filePath = segments.sublist(bucketIndex + 2).join('/');

      await _supabase.storage.from(bucket).remove([filePath]);
      if (kDebugMode) print('🗑️ Deleted: $filePath from $bucket');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting file: $e');
      return false;
    }
  }

  // ── Upload profile photo ──────────────────────────────────────────────────
  Future<String?> uploadProfilePhoto(File file, String userId) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = 'avatars/$userId.$ext';

      // Upsert = true so it replaces the existing photo
      await _supabase.storage.from(_imagesBucket).upload(
            fileName,
            file,
            fileOptions: FileOptions(
              contentType: _imageMimeType(ext),
              upsert: true,
            ),
          );

      // Add cache-busting query param so Flutter re-fetches the new photo
      final url = _supabase.storage.from(_imagesBucket).getPublicUrl(fileName);
      return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      if (kDebugMode) print('❌ Error uploading profile photo: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _imageMimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  String _videoMimeType(String ext) {
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'video/mp4';
    }
  }
}
