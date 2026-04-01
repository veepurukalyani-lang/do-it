import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  static final MediaService instance = MediaService._();
  MediaService._();

  final _uuid = const Uuid();

  /// Compresses an image based on the requirements:
  /// - Max width: 1080px
  /// - Format: WebP (or JPEG if preferred)
  /// - Quality: 80%
  /// - Removes EXIF metadata
  Future<XFile?> compressImage(XFile file) async {
    if (kIsWeb) return file; // Skip heavy compression on web for simplicity initially
    try {
      final targetPath = '${file.path}_compressed.webp';

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 80,
        minWidth: 1080,
        format: CompressFormat.webp,
        keepExif: false,
      );

      return result;
    } catch (e) {
      debugPrint('Image compression error: $e');
      return file;
    }
  }

  /// Generates a thumbnail for an image:
  /// - Width: 300px
  /// - Format: JPEG
  Future<XFile?> generateImageThumbnail(XFile file) async {
    if (kIsWeb) return file;
    try {
      final targetPath = '${file.path}_thumb.jpg';

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 70,
        minWidth: 300,
        format: CompressFormat.jpeg,
      );

      return result;
    } catch (e) {
      debugPrint('Image thumbnail error: $e');
      return file;
    }
  }

  /// Compresses a video based on requirements:
  /// - H.264/MP4
  /// - Max resolution: 720p
  /// - Bitrate: 2-3 Mbps
  /// - Aggressive compression if > 50MB
  Future<XFile?> compressVideo(XFile file, {void Function(double)? onProgress}) async {
    if (kIsWeb) return file; // Skip video compression on web for now
    try {
      // Check file size using web-safe methods if necessary, 
      // but if we are here and not kIsWeb, then it's native.
      final int fileSizeInBytes = await file.length();
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      
      VideoQuality quality = VideoQuality.DefaultQuality;
      if (fileSizeInMB > 50) {
        quality = VideoQuality.MediumQuality; // More aggressive
      }

      // Set up progress listener
      final subscription = VideoCompress.compressProgress$.subscribe((progress) {
        if (onProgress != null) {
          onProgress(progress);
        }
      });

      final MediaInfo? info = await VideoCompress.compressVideo(
        file.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      subscription.unsubscribe();

      if (info == null || info.file == null) return file;
      return XFile(info.file!.path);
    } catch (e) {
      debugPrint('Video compression error: $e');
      VideoCompress.cancelCompression();
      return file;
    }
  }

  /// Generates a thumbnail for a video:
  /// - Resolution: 720x1280 or scaled
  /// - Format: JPEG
  Future<XFile?> generateVideoThumbnail(XFile file) async {
    if (kIsWeb) return file;
    try {
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        file.path,
        quality: 70,
        position: -1, // Use default or random frame
      );
      
      return XFile(thumbnailFile.path);
    } catch (e) {
      debugPrint('Video thumbnail error: $e');
      return file;
    }
  }

  /// Cleans up temporary files generated during compression
  Future<void> dispose() async {
    await VideoCompress.deleteAllCache();
  }
}
