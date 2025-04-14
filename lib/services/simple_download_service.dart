import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/download_model.dart';
import '../utils/file_utils.dart';

class SimpleDownloadService {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, bool> _isPaused = {};
  final Map<String, String> _tempFilePaths = {};

  // Get file information from URL
  Future<Map<String, dynamic>> getFileInfo(String url) async {
    try {
      // Make a HEAD request to get file information
      final response = await _dio.head(
        url,
        options: Options(
          headers: {
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          followRedirects: true,
          validateStatus: (status) => status != null && (status < 500),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      // Get content length
      final contentLength = response.headers.value('content-length');

      // Get content type
      final contentType = response.headers.value('content-type');

      // Get content disposition (for filename)
      final contentDisposition = response.headers.value('content-disposition');

      // Extract filename from content disposition or URL
      String fileName = '';
      if (contentDisposition != null && contentDisposition.contains('filename=')) {
        final regex = RegExp('filename="(.*?)"');
        final match = regex.firstMatch(contentDisposition);
        if (match != null && match.groupCount >= 1) {
          fileName = match.group(1) ?? '';
        } else {
          final regex = RegExp(r'filename=(.*?)($|;)');
          final match = regex.firstMatch(contentDisposition);
          if (match != null && match.groupCount >= 1) {
            fileName = match.group(1) ?? '';
          }
        }
      }

      // If filename not found in content disposition, extract from URL
      if (fileName.isEmpty) {
        fileName = path.basename(Uri.parse(url).path);

        // If URL doesn't have a filename, use a default name
        if (fileName.isEmpty || !fileName.contains('.')) {
          fileName = 'download';

          // Add extension based on content type if available
          if (contentType != null) {
            final extension = FileUtils.getExtensionFromMime(contentType);
            if (extension.isNotEmpty) {
              fileName = '$fileName.$extension';
            }
          }
        }
      }

      // Clean up the filename
      fileName = FileUtils.sanitizeFileName(fileName);

      // Return file information
      return {
        'contentLength': contentLength,
        'contentType': contentType,
        'contentDisposition': contentDisposition,
        'fileName': fileName,
        'isDirectDownload': true,
        'originalUrl': url,
        'finalUrl': url,
      };
    } catch (e) {
      debugPrint('Error getting file info: $e');

      // Return basic information based on URL
      return {
        'contentLength': null,
        'contentType': null,
        'contentDisposition': null,
        'fileName': FileUtils.getFileNameFromUrl(url),
        'isDirectDownload': true,
        'originalUrl': url,
        'finalUrl': url,
      };
    }
  }

  // Start a download
  Future<DownloadItem> startDownload({
    required String url,
    required String downloadLocation,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(String) onError,
    String? id,
  }) async {
    debugPrint('Starting simple download for URL: $url');

    // Create a download ID if not provided
    final downloadId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('Download ID: $downloadId');

    // Create a cancel token for this download
    final cancelToken = CancelToken();
    _cancelTokens[downloadId] = cancelToken;
    debugPrint('Created cancel token for download ID: $downloadId');

    try {
      // Step 1: Get file information
      final fileInfo = await getFileInfo(url);
      final fileName = fileInfo['fileName'] as String;
      final contentType = fileInfo['contentType'] as String?;
      final contentLength = fileInfo['contentLength'] as String?;

      // Step 2: Calculate file size in MB
      final fileSize = contentLength != null ? double.parse(contentLength) / (1024 * 1024) : 0.0;

      // Step 3: Determine file type
      final fileType = FileUtils.getFileTypeFromMime(contentType ?? '') ??
                      path.extension(fileName).replaceAll('.', '');

      // Step 4: Create download item
      final downloadItem = DownloadItem(
        id: downloadId,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        url: url,
        status: DownloadStatus.downloading,
        progress: 0.0,
        speed: 0.0,
        remainingTime: 'Calculating...',
        startTime: DateTime.now(),
      );

      // Step 5: Get download path
      final filePath = path.join(downloadLocation, fileName);
      final tempFilePath = '$filePath.download';
      _tempFilePaths[downloadId] = tempFilePath;

      // Step 6: Setup progress tracking variables
      int startTime = DateTime.now().millisecondsSinceEpoch;
      int lastUpdateTime = startTime;
      int lastReceivedBytes = 0;
      List<double> speedSamples = [];

      // Step 7: Start the download
      await _dio.download(
        url,
        tempFilePath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(
          headers: {
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          followRedirects: true,
          validateStatus: (status) => status != null && (status < 500),
          receiveTimeout: const Duration(minutes: 30),
        ),
        onReceiveProgress: (received, total) {
          // Skip if download is paused
          if (_isPaused[downloadId] == true) {
            debugPrint('Download is paused, skipping progress update for ID: $downloadId');
            return;
          }

          // Log progress occasionally
          if (received % 1000000 == 0) { // Log every ~1MB
            debugPrint('Download progress for ID $downloadId: $received bytes received');
          }

          // Ensure total is valid
          final actualTotal = total != -1 ? total : (fileSize * 1024 * 1024).toInt();

          if (actualTotal > 0) {
            // Calculate progress percentage (ensure it's between 0 and 1)
            final progress = (received / actualTotal).clamp(0.0, 1.0);
            downloadItem.progress = progress;

            // Calculate download speed (bytes per second)
            final currentTime = DateTime.now().millisecondsSinceEpoch;
            final timeElapsed = (currentTime - lastUpdateTime) / 1000; // in seconds

            if (timeElapsed >= 0.5) { // Update every half second
              final bytesReceived = received - lastReceivedBytes;
              final speed = bytesReceived / timeElapsed; // bytes per second

              // Add to speed samples for smoothing
              speedSamples.add(speed);
              if (speedSamples.length > 5) {
                speedSamples.removeAt(0); // Keep only the last 5 samples
              }

              // Calculate average speed from samples
              final avgSpeed = speedSamples.reduce((a, b) => a + b) / speedSamples.length;

              // Convert to MB/s for display (with 2 decimal places)
              final speedInMBps = avgSpeed / (1024 * 1024);
              downloadItem.speed = double.parse(speedInMBps.toStringAsFixed(2));

              // Calculate remaining time
              if (avgSpeed > 0) {
                final remainingBytes = actualTotal - received;
                final remainingSeconds = remainingBytes / avgSpeed;
                downloadItem.remainingTime = FileUtils.formatDuration(remainingSeconds.toInt());
              }

              // Update for next calculation
              lastUpdateTime = currentTime;
              lastReceivedBytes = received;

              // Notify progress
              onProgress(downloadItem);
            }
          }
        },
      );

      // Step 8: Rename temp file to final file
      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.rename(filePath);
      }

      // Step 9: Download completed
      downloadItem.status = DownloadStatus.completed;
      downloadItem.progress = 1.0;
      downloadItem.speed = 0.0;
      downloadItem.remainingTime = '';
      downloadItem.localPath = filePath;
      downloadItem.endTime = DateTime.now();

      // Step 10: Clean up
      _cancelTokens.remove(downloadId);
      _isPaused.remove(downloadId);
      _tempFilePaths.remove(downloadId);

      // Step 11: Notify completion
      onComplete(downloadItem);

      return downloadItem;
    } catch (e) {
      // Check if the download was canceled or paused
      if (cancelToken.isCancelled) {
        if (_isPaused[downloadId] == true) {
          debugPrint('Download paused: $downloadId');

          // Create a paused download item
          final pausedItem = DownloadItem(
            id: downloadId,
            fileName: FileUtils.getFileNameFromUrl(url),
            fileType: '',
            fileSize: 0.0,
            url: url,
            status: DownloadStatus.paused,
            progress: 0.0,
            speed: 0.0,
            remainingTime: '',
          );

          return pausedItem;
        } else {
          debugPrint('Download canceled: $downloadId');
          onError('Download canceled');
        }
      } else {
        debugPrint('Download error: $e');
        onError('Download failed: ${e.toString()}');
      }

      // Clean up if not paused
      if (_isPaused[downloadId] != true) {
        _cancelTokens.remove(downloadId);
        _isPaused.remove(downloadId);
        _tempFilePaths.remove(downloadId);
      }

      // Create a failed download item
      final failedItem = DownloadItem(
        id: downloadId,
        fileName: FileUtils.getFileNameFromUrl(url),
        fileType: '',
        fileSize: 0.0,
        url: url,
        status: _isPaused[downloadId] == true ? DownloadStatus.paused : DownloadStatus.failed,
        progress: 0.0,
        speed: 0.0,
        remainingTime: '',
        errorMessage: e.toString(),
      );

      return failedItem;
    }
  }

  // Pause a download
  Future<void> pauseDownload(String id) async {
    debugPrint('=== PAUSE DOWNLOAD CALLED ===');
    debugPrint('Pausing simple download with ID: $id');

    // Mark the download as paused
    _isPaused[id] = true;
    debugPrint('Marked download as paused: $id');

    // Get the cancel token for this download
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      debugPrint('Found cancel token for download: $id');

      if (!cancelToken.isCancelled) {
        debugPrint('Cancel token is not yet cancelled, cancelling now');

        // Cancel the current download operation
        try {
          cancelToken.cancel('Download paused by user');
          debugPrint('Successfully cancelled download operation for ID: $id');
        } catch (e) {
          debugPrint('Error cancelling download: $e');
        }
      } else {
        debugPrint('Cancel token is already cancelled');
      }
    } else {
      debugPrint('No cancel token found for download ID: $id');
    }

    debugPrint('=== PAUSE DOWNLOAD COMPLETED ===');
  }

  // Resume a download
  Future<DownloadItem> resumeDownload({
    required String id,
    required String url,
    required String downloadLocation,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(String) onError,
  }) async {
    debugPrint('=== RESUME DOWNLOAD CALLED ===');
    debugPrint('Resuming simple download with ID: $id');

    // Mark the download as not paused
    _isPaused[id] = false;
    debugPrint('Marked download as not paused: $id');

    // Start a new download with the same ID
    return startDownload(
      id: id,
      url: url,
      downloadLocation: downloadLocation,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );
  }

  // Cancel a download
  Future<void> cancelDownload(String id) async {
    debugPrint('=== CANCEL DOWNLOAD CALLED ===');
    debugPrint('Canceling simple download with ID: $id');

    // Get the cancel token for this download
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      debugPrint('Found cancel token for download: $id');

      if (!cancelToken.isCancelled) {
        debugPrint('Cancel token is not yet cancelled, cancelling now');

        // Cancel the current download operation
        try {
          cancelToken.cancel('Download canceled by user');
          debugPrint('Successfully cancelled download operation for ID: $id');
        } catch (e) {
          debugPrint('Error cancelling download: $e');
        }
      } else {
        debugPrint('Cancel token is already cancelled');
      }
    } else {
      debugPrint('No cancel token found for download ID: $id');
    }

    // Clean up temp file if it exists
    final tempFilePath = _tempFilePaths[id];
    if (tempFilePath != null) {
      try {
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
          debugPrint('Deleted temp file: $tempFilePath');
        }
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
    }

    // Remove from maps
    _cancelTokens.remove(id);
    _isPaused.remove(id);
    _tempFilePaths.remove(id);

    debugPrint('=== CANCEL DOWNLOAD COMPLETED ===');
  }
}
