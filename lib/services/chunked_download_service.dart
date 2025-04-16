import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/download_model.dart';
import '../utils/file_utils.dart';

class ChunkedDownloadService {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, bool> _isPaused = {};
  final Map<String, bool> _pauseRequests = {};

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
          final regex = RegExp('filename=(.*?)(\$|;)');
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

  // Start or resume a download
  Future<DownloadItem> startDownload({
    required String url,
    required String downloadLocation,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(String) onError,
    String? id,
  }) async {
    debugPrint('Starting chunked download for URL: $url');

    // Create a download ID if not provided
    final downloadId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('=== START DOWNLOAD ===');
    debugPrint('Download ID: $downloadId');

    // Create a cancel token for this download
    final cancelToken = CancelToken();
    _cancelTokens[downloadId] = cancelToken;
    debugPrint('Created and stored cancel token for download ID: $downloadId');
    debugPrint('Current cancel tokens: ${_cancelTokens.keys.join(', ')}');

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
      final mainFilePath = path.join(downloadLocation, fileName);
      final mainFile = File(mainFilePath);

      // Step 6: Check if the file already exists
      final bool fileExists = await mainFile.exists();
      List<int> chunkSizes = [];

      if (fileExists) {
        // If file exists, get its size
        final fileLocalSize = await mainFile.length();
        chunkSizes.add(fileLocalSize);

        // Check for additional chunks
        int i = 1;
        String chunkPath = path.join(downloadLocation, '${path.basenameWithoutExtension(fileName)}_$i${path.extension(fileName)}');
        File chunkFile = File(chunkPath);

        while (await chunkFile.exists()) {
          chunkSizes.add(await chunkFile.length());
          i++;
          chunkPath = path.join(downloadLocation, '${path.basenameWithoutExtension(fileName)}_$i${path.extension(fileName)}');
          chunkFile = File(chunkPath);
        }

        // Set the path for the next chunk
        final nextChunkPath = chunkPath;

        // Calculate total downloaded bytes
        final totalDownloaded = chunkSizes.fold(0, (sum, size) => sum + size);

        // Update progress
        if (contentLength != null) {
          final totalBytes = int.parse(contentLength);
          downloadItem.progress = totalDownloaded / totalBytes;
        }

        // Set up range header for resuming download
        final options = Options(
          headers: {
            'Range': 'bytes=$totalDownloaded-',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          followRedirects: true,
          validateStatus: (status) => status != null && (status < 500),
          receiveTimeout: const Duration(minutes: 30),
        );

        // Setup progress tracking variables
        int startTime = DateTime.now().millisecondsSinceEpoch;
        int lastUpdateTime = startTime;
        int lastReceivedBytes = 0;
        List<double> speedSamples = [];

        // Start the download
        await _dio.download(
          url,
          nextChunkPath,
          cancelToken: cancelToken,
          deleteOnError: false,
          options: options,
          onReceiveProgress: (received, total) {
            // Check if a pause has been requested
            if (_pauseRequests[downloadId] == true) {
              cancelToken.cancel('Pause requested by user');
              return;
            }

            // Skip if download is paused
            if (_isPaused[downloadId] == true) {
              debugPrint('Download is paused, skipping progress update for ID: $downloadId');
              return;
            }

            // Log progress occasionally
            if (received % 1000000 == 0) { // Log every ~1MB
              debugPrint('Download progress for ID $downloadId: $received bytes received');
              debugPrint('Pause status: ${_isPaused[downloadId]}');
            }

            // Ensure total is valid
            final actualTotal = total != -1 ? total : (fileSize * 1024 * 1024).toInt();

            if (actualTotal > 0) {
              // Calculate progress percentage (ensure it's between 0 and 1)
              // Add the bytes we've already downloaded to the received bytes
              final totalReceived = totalDownloaded + received;
              final progress = (totalReceived / actualTotal).clamp(0.0, 1.0);
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
                  final remainingBytes = actualTotal - totalReceived;
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

        // Merge all chunks into the main file
        await _mergeChunks(mainFilePath, downloadLocation);

        // Download completed
        downloadItem.status = DownloadStatus.completed;
        downloadItem.progress = 1.0;
        downloadItem.speed = 0.0;
        downloadItem.remainingTime = '';
        downloadItem.localPath = mainFilePath;
        downloadItem.endTime = DateTime.now();

        // Remove the cancel token
        _cancelTokens.remove(downloadId);
        _isPaused.remove(downloadId);

        onComplete(downloadItem);
      } else {
        // If file doesn't exist, start a new download
        // Setup progress tracking variables
        int startTime = DateTime.now().millisecondsSinceEpoch;
        int lastUpdateTime = startTime;
        int lastReceivedBytes = 0;
        List<double> speedSamples = [];

        // Start the download
        await _dio.download(
          url,
          mainFilePath,
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
            // Check if a pause has been requested
            if (_pauseRequests[downloadId] == true) {
              cancelToken.cancel('Pause requested by user');
              return;
            }

            // Skip if download is paused
            if (_isPaused[downloadId] == true) {
              debugPrint('Download is paused (new file), skipping progress update for ID: $downloadId');
              return;
            }

            // Log progress occasionally
            if (received % 1000000 == 0) { // Log every ~1MB
              debugPrint('Download progress (new file) for ID $downloadId: $received bytes received');
              debugPrint('Pause status: ${_isPaused[downloadId]}');
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

        // Download completed
        downloadItem.status = DownloadStatus.completed;
        downloadItem.progress = 1.0;
        downloadItem.speed = 0.0;
        downloadItem.remainingTime = '';
        downloadItem.localPath = mainFilePath;
        downloadItem.endTime = DateTime.now();

        // Remove the cancel token
        _cancelTokens.remove(downloadId);
        _isPaused.remove(downloadId);

        onComplete(downloadItem);
      }

      return downloadItem;
    } catch (e) {
      // Check if the download was canceled or paused
      if (cancelToken.isCancelled) {
        if (_isPaused[downloadId] == true) {
          debugPrint('Download paused: $downloadId');
          onError('Download paused');
        } else {
          debugPrint('Download canceled: $downloadId');
          onError('Download canceled');
        }
      } else {
        debugPrint('Download error: $e');
        onError('Download failed: ${e.toString()}');
      }

      // Remove the cancel token if not paused
      if (_isPaused[downloadId] != true) {
        _cancelTokens.remove(downloadId);
        _isPaused.remove(downloadId);
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
    debugPrint('Pausing chunked download with ID: $id');

    // Print the current state of the maps
    debugPrint('Current cancel tokens: ${_cancelTokens.keys.join(', ')}');
    debugPrint('Current paused downloads: ${_isPaused.keys.join(', ')}');

    // Mark the pause request
    _pauseRequests[id] = true;
    debugPrint('Marked pause request for download: $id');
    // Mark the download as paused
    _isPaused[id] = true;
    debugPrint('Marked download as paused: $id');

    // Get the cancel token for this download
    if (cancelToken != null) {
      if (!cancelToken.isCancelled) {
        debugPrint('Found cancel token for download: $id');
        debugPrint('Cancel token is not yet cancelled, cancelling now');
        // Cancel the current download operation
        cancelToken.cancel('Download paused by user');
        debugPrint('Successfully cancelled download operation for ID: $id');
      } else{

        debugPrint('Cancel token is already cancelled');
      }
    } else {
      debugPrint('No cancel token found for download ID: $id');
    }
    
    // Remove the pause request
    _pauseRequests.remove(id);

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
    debugPrint('Resuming chunked download with ID: $id');

    // Mark the download as not paused
    _isPaused[id] = false;

    // Start the download with the same ID
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
    debugPrint('Canceling chunked download with ID: $id');

    // Get the cancel token for this download
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      debugPrint('Found active cancel token for download: $id');

      // Cancel the current download operation
      cancelToken.cancel('Download canceled by user');
      debugPrint('Cancelled download operation for ID: $id');
    } else {
      debugPrint('No active cancel token found for download ID: $id');
    }

    // Remove from maps
    _cancelTokens.remove(id);
    _isPaused.remove(id);
    _pauseRequests.remove(id);
  }

  // Merge all chunks into the main file
  Future<void> _mergeChunks(String mainFilePath, String downloadLocation) async {
    final mainFile = File(mainFilePath);
    final fileName = path.basename(mainFilePath);
    final baseName = path.basenameWithoutExtension(fileName);
    final extension = path.extension(fileName);

    // Check if there are any chunks to merge
        int i = 1;
        String chunkPath = path.join(downloadLocation, '${baseName}_$i$extension');
        File chunkFile = File(chunkPath);

        // Check for the first complete chunk, if none exist exit
        String completeChunkPath = '$chunkPath.complete';
        File completeChunkFile = File(completeChunkPath);

    if (!await completeChunkFile.exists()) {
      // No chunks to merge
      return;
    }

    // Open the main file for appending
    final mainFileRaf = await mainFile.open(mode: FileMode.writeOnlyAppend);

    // Merge all chunks
        while (await completeChunkFile.exists()) {
          // Read chunk and append to main file
          final chunkBytes = await chunkFile.readAsBytes();
          await mainFileRaf.writeFrom(chunkBytes);

          // Delete the chunk and the complete marker
          await chunkFile.delete();
          await completeChunkFile.delete();

          // Move to next chunk
          i++;
          chunkPath = path.join(downloadLocation, '${baseName}_$i$extension');
          chunkFile = File(chunkPath);
          completeChunkPath = '$chunkPath.complete';
          completeChunkFile = File(completeChunkPath);

    }

    // Close the main file
    await mainFileRaf.close();
  }
}
