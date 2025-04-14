import 'dart:math' as math;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

class FileUtils {
  static String getFileNameFromUrl(String url) {
    try {
      // First, try to parse the URL
      Uri uri = Uri.parse(url);
      String fileName = path.basename(uri.path);

      // Check if the filename has a query string and remove it
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }

      // Check if the filename has URL encoded characters and decode them
      if (fileName.contains('%')) {
        fileName = Uri.decodeComponent(fileName);
      }

      // If no filename in URL or it doesn't have an extension, try to extract from Content-Disposition header
      // This will be handled in the download service

      // If still no valid filename, generate one
      if (fileName.isEmpty || !fileName.contains('.')) {
        // Generate a timestamp-based filename with a more readable format
        final now = DateTime.now();
        final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
        fileName = 'download_$timestamp';

        // Try to add extension based on content type
        final contentType = lookupMimeType(url);
        if (contentType != null) {
          final extension = getExtensionFromMime(contentType);
          if (extension.isNotEmpty) {
            fileName = '$fileName.$extension';
          }
        }
      }

      // Remove any invalid characters from the filename
      fileName = _sanitizeFileName(fileName);

      return fileName;
    } catch (e) {
      // Fallback to a simple timestamp if URL parsing fails
      return 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
    }
  }

  // Sanitize filename to remove invalid characters
  static String _sanitizeFileName(String fileName) {
    // Replace characters that are invalid in filenames
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    return fileName.replaceAll(invalidChars, '_');
  }

  // Public method for sanitizing filenames
  static String sanitizeFileName(String fileName) {
    return _sanitizeFileName(fileName);
  }

  // Extract filename from Content-Disposition header
  static String? getFileNameFromContentDisposition(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.isEmpty) {
      return null;
    }

    // Try to extract filename from Content-Disposition header
    // Example: attachment; filename="filename.jpg"
    final regExp = RegExp('filename[^;=\n]*=([\'"]?)([^;\n]*)(\\1)');
    final matches = regExp.firstMatch(contentDisposition);

    if (matches != null && matches.groupCount >= 1) {
      String fileName = matches.group(1) ?? '';

      // Remove quotes if present
      if (fileName.startsWith('"') && fileName.endsWith('"')) {
        fileName = fileName.substring(1, fileName.length - 1);
      }

      // Remove any invalid characters
      fileName = _sanitizeFileName(fileName);

      return fileName.isNotEmpty ? fileName : null;
    }

    return null;
  }

  static String? getFileTypeFromMime(String mimeType) {
    if (mimeType.isEmpty) return null;

    final parts = mimeType.split('/');
    if (parts.length < 2) return null;

    final mainType = parts[0];
    final subType = parts[1];

    switch (mainType) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'text':
        return 'Document';
      case 'application':
        switch (subType) {
          case 'pdf':
            return 'PDF';
          case 'msword':
          case 'vnd.openxmlformats-officedocument.wordprocessingml.document':
            return 'Document';
          case 'vnd.ms-excel':
          case 'vnd.openxmlformats-officedocument.spreadsheetml.sheet':
            return 'Spreadsheet';
          case 'vnd.ms-powerpoint':
          case 'vnd.openxmlformats-officedocument.presentationml.presentation':
            return 'Presentation';
          case 'zip':
          case 'x-zip-compressed':
          case 'x-rar-compressed':
          case 'x-7z-compressed':
            return 'Archive';
          case 'x-msdownload':
          case 'octet-stream':
            return 'Executable';
          default:
            return 'Other';
        }
      default:
        return 'Other';
    }
  }

  static String getExtensionFromMime(String mimeType) {
    switch (mimeType) {
      case 'application/pdf':
        return 'pdf';
      case 'application/zip':
      case 'application/x-zip-compressed':
        return 'zip';
      case 'application/x-rar-compressed':
        return 'rar';
      case 'application/x-7z-compressed':
        return '7z';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'application/vnd.ms-excel':
        return 'xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      case 'application/vnd.ms-powerpoint':
        return 'ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';
      case 'text/plain':
        return 'txt';
      case 'text/html':
        return 'html';
      case 'text/css':
        return 'css';
      case 'text/javascript':
      case 'application/javascript':
        return 'js';
      case 'application/json':
        return 'json';
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/svg+xml':
        return 'svg';
      case 'audio/mpeg':
        return 'mp3';
      case 'audio/wav':
        return 'wav';
      case 'audio/ogg':
        return 'ogg';
      case 'video/mp4':
        return 'mp4';
      case 'video/mpeg':
        return 'mpeg';
      case 'video/webm':
        return 'webm';
      case 'video/quicktime':
        return 'mov';
      case 'application/x-bittorrent':
        return 'torrent';
      default:
        // Extract extension from mime type
        final parts = mimeType.split('/');
        if (parts.length == 2) {
          return parts[1].split(';')[0]; // Remove parameters
        }
        return '';
    }
  }

  static fluent.IconData getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return fluent.FluentIcons.pdf;
      case 'doc':
      case 'docx':
        return fluent.FluentIcons.document;
      case 'xls':
      case 'xlsx':
        return fluent.FluentIcons.excel_document;
      case 'ppt':
      case 'pptx':
        return fluent.FluentIcons.document;
      case 'txt':
        return fluent.FluentIcons.text_document;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return fluent.FluentIcons.folder;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'svg':
      case 'bmp':
        return fluent.FluentIcons.photo2;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'flac':
      case 'aac':
        return fluent.FluentIcons.music_note;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'mkv':
      case 'webm':
      case 'flv':
        return fluent.FluentIcons.video;
      case 'exe':
      case 'msi':
        return fluent.FluentIcons.installation;
      case 'apk':
        return fluent.FluentIcons.document;
      case 'torrent':
        return fluent.FluentIcons.download;
      case 'html':
      case 'htm':
      case 'css':
      case 'js':
        return fluent.FluentIcons.code;
      default:
        return fluent.FluentIcons.document;
    }
  }

  static IconData getMaterialFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'svg':
      case 'bmp':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'flac':
      case 'aac':
        return Icons.audio_file;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'mkv':
      case 'webm':
      case 'flv':
        return Icons.video_file;
      case 'exe':
      case 'msi':
        return Icons.apps;
      case 'apk':
        return Icons.android;
      case 'torrent':
        return Icons.download;
      case 'html':
      case 'htm':
      case 'css':
      case 'js':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  static String formatFileSize(double fileSizeInMB) {
    if (fileSizeInMB < 1) {
      return '${(fileSizeInMB * 1024).toStringAsFixed(1)} KB';
    } else if (fileSizeInMB < 1024) {
      return '${fileSizeInMB.toStringAsFixed(1)} MB';
    } else {
      return '${(fileSizeInMB / 1024).toStringAsFixed(2)} GB';
    }
  }

  // Format bytes to human-readable size
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds sec remaining';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} remaining';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours:${minutes.toString().padLeft(2, '0')} remaining';
    }
  }

  static Color getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'svg':
        return Colors.teal;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Colors.deepPurple;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Colors.red.shade700;
      case 'exe':
      case 'msi':
      case 'apk':
        return Colors.grey.shade700;
      default:
        return Colors.blueGrey;
    }
  }
}
