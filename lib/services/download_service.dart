import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../models/download_model.dart';
import '../utils/file_utils.dart';

class DownloadService {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Map<String, dynamic>> _pausedDownloads = {}; // Store info about paused downloads

  // Constructor with optional configuration
  DownloadService() {
    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // Add interceptors for logging if needed
    _dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      requestBody: false,
      responseHeader: true,
      responseBody: false,
    ));
  }

  Future<String> _getDownloadPath(String fileName, String customPath) async {
    Directory? directory;

    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) {
        directory = Directory('/storage/emulated/0/Download');
        // Create the directory if it doesn't exist
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getTemporaryDirectory();
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Desktop platforms
      if (customPath.isNotEmpty) {
        directory = Directory(customPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getDownloadsDirectory();
      }
    }

    if (directory == null) {
      throw Exception('Could not determine download directory');
    }

    return path.join(directory.path, fileName);
  }

  Future<DownloadItem> startDownload({
    required String url,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(String) onError,
    required String downloadLocation,
  }) async {
    debugPrint('Starting download for URL: $url');

    // Create a cancel token for this download
    final cancelToken = CancelToken();

    try {
      // Step 1: Get file information using our improved method
      final fileInfo = await getFileInfo(url);

      // Get the final URL after redirects and check if it's a file hosting site
      final finalUrl = fileInfo['finalUrl'] as String? ?? url;
      final isFileHostingSite = fileInfo['isFileHostingSite'] as bool? ?? false;

      // Only block known file hosting sites that definitely require manual interaction
      if (isFileHostingSite) {
        // For known file hosting sites, provide a specific message
        final errorMessage = 'This URL is from ${Uri.parse(url).host} which requires manual interaction. '
                   'Please open this link in a browser to download the file.';

        // Inform the user
        onError(errorMessage);

        // Create a failed download item to return
        final failedItem = DownloadItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: fileInfo['fileName'] as String? ?? 'Unknown file',
          fileType: '',
          fileSize: 0.0,
          url: url,
          status: DownloadStatus.failed,
          progress: 0.0,
          speed: 0.0,
          remainingTime: '',
          errorMessage: errorMessage,
        );

        return failedItem;
      }

      // Extract information from fileInfo
      final contentLength = fileInfo['contentLength'] as String?;
      final contentType = fileInfo['contentType'] as String?;
      String fileName = fileInfo['fileName'] as String? ?? 'download.bin';

      // Step 4: Calculate file size in MB
      final fileSize = contentLength != null ? double.parse(contentLength) / (1024 * 1024) : 0.0;

      // Step 5: Determine file type
      final fileType = FileUtils.getFileTypeFromMime(contentType ?? '') ??
                      path.extension(fileName).replaceAll('.', '');

      // Step 6: Create download item
      final downloadId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('Generated download ID: $downloadId');

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

      // Store the cancel token
      _cancelTokens[downloadItem.id] = cancelToken;
      debugPrint('Stored cancel token for download ID: ${downloadItem.id}');

      // Step 7: Get download path
      final savePath = await _getDownloadPath(fileName, downloadLocation);

      // Step 8: Setup progress tracking variables
      int startTime = DateTime.now().millisecondsSinceEpoch;
      int lastUpdateTime = startTime;
      int lastReceivedBytes = 0;
      List<double> speedSamples = [];

      // Step 9: Create a new cancel token for the actual download
      final downloadCancelToken = CancelToken();
      _cancelTokens[downloadItem.id] = downloadCancelToken;

      // Step 10: Start the actual download with progress tracking
      await _dio.download(
        finalUrl, // Use the final URL after redirects
        savePath,
        cancelToken: downloadCancelToken,
        deleteOnError: true,
        lengthHeader: Headers.contentLengthHeader,
        options: Options(
          headers: {
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(minutes: 30),
        ),
        onReceiveProgress: (received, total) {
          // Ensure total is valid
          final actualTotal = total != -1 ? total : (downloadItem.fileSize * 1024 * 1024).toInt();

          if (actualTotal > 0) {
            // Calculate progress percentage (ensure it's between 0 and 1)
            final progress = (received / actualTotal).clamp(0.0, 1.0);
            downloadItem.progress = progress;

            // Calculate download speed (bytes per second)
            final currentTime = DateTime.now().millisecondsSinceEpoch;
            final timeElapsed = (currentTime - lastUpdateTime) / 1000; // in seconds

            if (timeElapsed >= 0.2) { // Update more frequently (every 200ms)
              final bytesReceived = received - lastReceivedBytes;
              final speed = bytesReceived / timeElapsed; // bytes per second

              // Add to speed samples for smoothing
              speedSamples.add(speed);
              if (speedSamples.length > 5) {
                speedSamples.removeAt(0); // Keep only the last 5 samples
              }

              // Calculate average speed from samples
              final avgSpeed = speedSamples.isNotEmpty ?
                  speedSamples.reduce((a, b) => a + b) / speedSamples.length : 0;

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

      // Step 11: Verify the downloaded file exists
      final file = File(savePath);
      if (!await file.exists()) {
        throw Exception('Download failed: File not found at $savePath');
      }

      // Step 12: Download completed
      downloadItem.status = DownloadStatus.completed;
      downloadItem.progress = 1.0;
      downloadItem.speed = 0.0;
      downloadItem.remainingTime = '';
      downloadItem.localPath = savePath;
      downloadItem.endTime = DateTime.now();

      // Remove the cancel token
      _cancelTokens.remove(downloadItem.id);

      onComplete(downloadItem);
      return downloadItem;

    } catch (e) {
      // Check if the download was canceled
      if (cancelToken.isCancelled) {
        onError('Download canceled');
      } else {
        onError(e.toString());
      }

      // Remove the cancel token if it exists
      if (_cancelTokens.containsValue(cancelToken)) {
        _cancelTokens.removeWhere((key, value) => value == cancelToken);
      }

      // Create a failed download item to return
      final failedItem = DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: 'Failed download',
        fileType: '',
        fileSize: 0.0,
        url: url,
        status: DownloadStatus.failed,
        progress: 0.0,
        speed: 0.0,
        remainingTime: '',
        errorMessage: e.toString(),
      );

      return failedItem;
    }
  }

  Future<void> cancelDownload(String id) async {
    debugPrint('Canceling download with ID: $id');

    // Cancel the download if it's in progress
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      debugPrint('Found active cancel token for download: $id');
      cancelToken.cancel('Download canceled by user');
      _cancelTokens.remove(id);
      debugPrint('Cancelled download operation for ID: $id');
    } else {
      debugPrint('No active cancel token found for download ID: $id');
    }

    // Remove from paused downloads if it exists
    if (_pausedDownloads.containsKey(id)) {
      debugPrint('Removing paused download info for ID: $id');
      _pausedDownloads.remove(id);
    }

    // Try to delete the partial file
    try {
      final downloadManager = DownloadManager(); // This is not ideal, should be injected
      final download = downloadManager.downloads.firstWhere((item) => item.id == id);
      if (download.localPath != null) {
        final file = File(download.localPath!);
        if (await file.exists()) {
          debugPrint('Deleting partial file: ${download.localPath}');
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting partial file: $e');
      // Ignore errors when trying to delete the file
    }
  }

  Future<void> pauseDownload(String id) async {
    debugPrint('Pausing download with ID: $id');

    // Get the cancel token for this download
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      debugPrint('Found active cancel token for download: $id');

      // Get download information before canceling
      final downloadManager = DownloadManager();
      try {
        final download = downloadManager.downloads.firstWhere((item) => item.id == id);
        debugPrint('Found download in manager: ${download.fileName} with progress: ${download.progress}');

        // Store information about the paused download
        _pausedDownloads[id] = {
          'url': download.url,
          'fileName': download.fileName,
          'fileType': download.fileType,
          'fileSize': download.fileSize,
          'progress': download.progress,
          'localPath': download.localPath,
        };
        debugPrint('Stored paused download info for ID: $id');

        // Cancel the current download operation
        cancelToken.cancel('Download paused by user');
        _cancelTokens.remove(id);
        debugPrint('Cancelled download operation for ID: $id');
      } catch (e) {
        debugPrint('Error pausing download: $e');
      }
    } else {
      debugPrint('No active cancel token found for download ID: $id');
    }
  }

  Future<DownloadItem?> resumeDownload({
    required String id,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(String) onError,
    required String downloadLocation,
  }) async {
    debugPrint('Resuming download with ID: $id');

    // Check if we have information about this paused download
    final pausedInfo = _pausedDownloads[id];
    if (pausedInfo == null) {
      debugPrint('No paused download info found for ID: $id');
      onError('Cannot resume download: no information found');
      return null;
    }

    debugPrint('Found paused download info for ID: $id');

    final url = pausedInfo['url'] as String;
    final fileName = pausedInfo['fileName'] as String;
    final fileType = pausedInfo['fileType'] as String;
    final fileSize = pausedInfo['fileSize'] as double;
    final progress = pausedInfo['progress'] as double;
    final localPath = pausedInfo['localPath'] as String?;

    // Create a new download item with the paused information
    final downloadItem = DownloadItem(
      id: id,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      url: url,
      status: DownloadStatus.downloading,
      progress: progress,
      speed: 0.0,
      remainingTime: 'Calculating...',
      localPath: localPath,
    );

    // Remove from paused downloads
    _pausedDownloads.remove(id);

    // Get the path where the file should be saved
    final savePath = localPath ?? await _getDownloadPath(fileName, downloadLocation);

    // Create a new cancel token for the resumed download
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      // Get file information to determine the total size
      final fileInfo = await getFileInfo(url);
      final contentLength = fileInfo['contentLength'] as String?;
      final totalBytes = contentLength != null ? int.parse(contentLength) : (fileSize * 1024 * 1024).toInt();

      // Calculate how many bytes we've already downloaded
      final bytesAlreadyDownloaded = (progress * totalBytes).toInt();

      // Setup progress tracking variables
      int startTime = DateTime.now().millisecondsSinceEpoch;
      int lastUpdateTime = startTime;
      int lastReceivedBytes = bytesAlreadyDownloaded;
      List<double> speedSamples = [];

      // Start the download with a range request to resume from where we left off
      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        deleteOnError: false, // Don't delete on error since we're resuming
        options: Options(
          headers: {
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Range': 'bytes=$bytesAlreadyDownloaded-', // Resume from where we left off
          },
          followRedirects: true,
          validateStatus: (status) => status != null && (status < 500),
          receiveTimeout: const Duration(minutes: 30),
        ),
        onReceiveProgress: (received, total) {
          // Ensure total is valid
          final actualTotal = total != -1 ? total : totalBytes;

          if (actualTotal > 0) {
            // Calculate progress percentage (ensure it's between 0 and 1)
            // Add the bytes we've already downloaded to the received bytes
            final totalReceived = bytesAlreadyDownloaded + received;
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

      // Download completed
      downloadItem.status = DownloadStatus.completed;
      downloadItem.progress = 1.0;
      downloadItem.speed = 0.0;
      downloadItem.remainingTime = '';
      downloadItem.localPath = savePath;
      downloadItem.endTime = DateTime.now();

      // Remove the cancel token
      _cancelTokens.remove(id);

      onComplete(downloadItem);
      return downloadItem;

    } catch (e) {
      // Check if the download was canceled
      if (cancelToken.isCancelled) {
        onError('Download paused');
      } else {
        onError('Resume failed: ${e.toString()}');
      }

      // Remove the cancel token
      _cancelTokens.remove(id);

      return null;
    }
  }

  // Helper method to check if a URL is from a known file hosting site
  bool isFileHostingSite(String url) {
    try {
      final uri = Uri.parse(url.toLowerCase());
      final host = uri.host;

      // List of known file hosting sites that require manual interaction
      // This is a much more limited list of sites that definitely need manual interaction
      final fileHostingSites = [
        'workupload.com',
        'f82.workupload.com',
        'mega.nz',
        'rapidgator.net',
        'nitroflare.com',
        'turbobit.net',
        'hitfile.net',
        'uploadgig.com',
        'filerio.in',
      ];

      return fileHostingSites.any((site) => host == site || host.endsWith('.$site'));
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getFileInfo(String url) async {
    try {
      // Create a cancel token for this request
      final cancelToken = CancelToken();
      Response headResponse;
      String finalUrl = url; // Track the final URL after redirects
      bool isDirectDownload = true;

      // Step 1: Try HEAD request first to get file info without downloading content
      try {
        headResponse = await _dio.head(
          url,
          cancelToken: cancelToken,
          options: Options(
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'Accept': '*/*',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
          ),
        );

        // Check if we got redirected
        if (headResponse.redirects.isNotEmpty) {
          finalUrl = headResponse.redirects.last.location.toString();
        }

        // Check if we're getting HTML instead of a file
        final contentType = headResponse.headers.map['content-type']?[0] ?? '';
        if (contentType.contains('text/html')) {
          isDirectDownload = false;
        }
      } catch (e) {
        // If HEAD request fails, we'll try a GET request with responseType: ResponseType.stream
        // to get the headers without downloading the entire file
        try {
          final response = await _dio.get(
            url,
            options: Options(
              responseType: ResponseType.stream,
              followRedirects: true,
              validateStatus: (status) => status != null && status < 500,
              headers: {
                'Accept': '*/*',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              },
            ),
            cancelToken: cancelToken,
          );

          // Cancel the request after getting headers
          cancelToken.cancel();

          headResponse = response;

          // Check if we got redirected
          if (response.redirects.isNotEmpty) {
            finalUrl = response.redirects.last.location.toString();
          }

          // Check if we're getting HTML instead of a file
          final contentType = response.headers.map['content-type']?[0] ?? '';
          if (contentType.contains('text/html')) {
            isDirectDownload = false;
          }
        } catch (e) {
          // If both methods fail, create a default response
          headResponse = Response(
            requestOptions: RequestOptions(path: url),
            statusCode: 200,
            headers: Headers(),
          );
        }
      }

      // Step 2: Extract content information
      final contentLength = headResponse.headers.map['content-length']?[0];
      final contentType = headResponse.headers.map['content-type']?[0] ?? '';
      final contentDisposition = headResponse.headers.map['content-disposition']?[0];

      // Check if this is a known file hosting site that requires manual interaction
      if (isFileHostingSite(url)) {
        // For file hosting sites, we need to extract the actual download link
        // This is a placeholder - in a real implementation, you would parse the HTML
        // and extract the actual download link

        // For now, we'll just use the original URL and set a flag
        return {
          'contentLength': null,
          'contentType': null,
          'contentDisposition': null,
          'fileName': FileUtils.sanitizeFileName(FileUtils.getFileNameFromUrl(finalUrl)),
          'isDirectDownload': false,
          'originalUrl': url,
          'finalUrl': finalUrl,
          'isFileHostingSite': true
        };
      }

      // Even if we get HTML, we'll try to download it anyway
      // Many sites return HTML headers but actually serve files

      // Step 3: Try to get filename from Content-Disposition header first
      String? fileName = FileUtils.getFileNameFromContentDisposition(contentDisposition);

      // If not found in Content-Disposition, extract from URL
      if (fileName == null || fileName.isEmpty) {
        fileName = FileUtils.getFileNameFromUrl(finalUrl);
      }

      // Make sure the filename is valid and sanitized
      fileName = FileUtils.sanitizeFileName(fileName);

      // Step 4: Return the file information
      return {
        'contentLength': contentLength,
        'contentType': contentType,
        'contentDisposition': contentDisposition,
        'fileName': fileName,
        'isDirectDownload': isDirectDownload,
        'originalUrl': url,
        'finalUrl': finalUrl,
        'isFileHostingSite': isFileHostingSite(url)
      };
    } catch (e) {
      // If all attempts fail, return basic info
      return {
        'contentLength': null,
        'contentType': null,
        'contentDisposition': null,
        'fileName': FileUtils.sanitizeFileName(FileUtils.getFileNameFromUrl(url)),
        'isDirectDownload': false,
        'originalUrl': url,
        'finalUrl': url,
        'isFileHostingSite': isFileHostingSite(url)
      };
    }
  }
}
