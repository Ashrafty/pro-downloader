import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../models/download_model.dart';
import '../utils/file_utils.dart';

class DownloadService {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  
  // Constructor with optional configuration
  DownloadService() {
    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    
    // Add interceptors for logging if needed
    _dio.interceptors.add(LogInterceptor(
      requestHeader: true,
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
  
  Future<Map<String, dynamic>> getFileInfo(String url) async {
    try {
      // First try a HEAD request to get file information
      Response<dynamic> headResponse;
      try {
        headResponse = await _dio.head(
          url,
          options: Options(
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
          ),
        );
      } catch (e) {
        // If HEAD request fails, try a GET request with range header to get file info without downloading the whole file
        headResponse = await _dio.get(
          url,
          options: Options(
            headers: {
              'Range': 'bytes=0-0',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      }
      
      final contentType = headResponse.headers.map['content-type']?[0];
      final contentLength = headResponse.headers.map['content-length']?[0];
      final contentDisposition = headResponse.headers.map['content-disposition']?[0];
      
      return {
        'contentType': contentType,
        'contentLength': contentLength,
        'contentDisposition': contentDisposition,
        'statusCode': headResponse.statusCode,
        'redirectUrl': headResponse.redirects.isNotEmpty ? headResponse.redirects.last.location.toString() : null,
      };
    } catch (e) {
      print('Error getting file info: $e');
      return {};
    }
  }
  
  Future<DownloadItem> startDownload({
    required String url,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(String) onError,
    required String downloadLocation,
  }) async {
    // Create a cancel token for this download
    final cancelToken = CancelToken();
    
    try {
      // Get file information from URL with a HEAD request first
      final fileInfo = await getFileInfo(url);
      
      // Check if the request was successful
      final statusCode = fileInfo['statusCode'] as int?;
      if (statusCode == null || statusCode < 200 || statusCode >= 400) {
        throw Exception('Failed to get file information. Status code: $statusCode');
      }
      
      // Use the redirect URL if available
      final finalUrl = fileInfo['redirectUrl'] as String? ?? url;
      
      // Extract content information
      final contentLength = fileInfo['contentLength'] as String?;
      final contentType = fileInfo['contentType'] as String?;
      final contentDisposition = fileInfo['contentDisposition'] as String?;
      
      // Try to get filename from Content-Disposition header first
      String? fileName = FileUtils.getFileNameFromContentDisposition(contentDisposition);
      
      // If not found in Content-Disposition, extract from URL
      if (fileName == null || fileName.isEmpty) {
        fileName = FileUtils.getFileNameFromUrl(finalUrl);
      }
      
      // Calculate file size in MB
      final fileSize = contentLength != null ? double.parse(contentLength) / (1024 * 1024) : 0.0;
      
      // Determine file type
      final fileType = FileUtils.getFileTypeFromMime(contentType ?? '') ?? 
                      path.extension(fileName).replaceAll('.', '');
      
      // Create download item
      final downloadItem = DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        url: finalUrl,
        status: DownloadStatus.downloading,
        progress: 0.0,
        speed: 0.0,
        remainingTime: 'Calculating...',
        startTime: DateTime.now(),
      );
      
      // Store the cancel token
      _cancelTokens[downloadItem.id] = cancelToken;
      
      // Get download path
      final savePath = await _getDownloadPath(fileName, downloadLocation);
      
      // Check if file already exists and delete it if it does
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Setup progress tracking variables
      int startTime = DateTime.now().millisecondsSinceEpoch;
      int lastUpdateTime = startTime;
      int lastReceivedBytes = 0;
      List<double> speedSamples = [];
      
      // Start download with progress tracking
      final response = await _dio.download(
        finalUrl,
        savePath,
        cancelToken: cancelToken,
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
          // If total is -1, we don't know the total size
          final actualTotal = total != -1 ? total : (fileSize > 0 ? (fileSize * 1024 * 1024).toInt() : received * 2);
          
          // Calculate progress percentage
          final progress = received / actualTotal;
          downloadItem.progress = progress.clamp(0.0, 0.99); // Cap at 99% until verified
          
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
            
            // Convert to MB/s for display
            downloadItem.speed = avgSpeed / (1024 * 1024);
            
            // Calculate remaining time
            if (avgSpeed > 0) {
              final remainingBytes = actualTotal - received;
              final remainingSeconds = remainingBytes / avgSpeed;
              downloadItem.remainingTime = FileUtils.formatDuration(remainingSeconds.toInt());
            }
            
            // Update for next calculation
            lastUpdateTime = currentTime;
            lastReceivedBytes = received;
          }
          
          // Notify progress
          onProgress(downloadItem);
        },
      );
      
      // Verify the download was successful
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Download failed with status code: ${response.statusCode}');
      }
      
      // Verify the file exists and has content
      final downloadedFile = File(savePath);
      if (!await downloadedFile.exists()) {
        throw Exception('Downloaded file does not exist');
      }
      
      final fileStats = await downloadedFile.stat();
      if (fileStats.size == 0) {
        throw Exception('Downloaded file is empty');
      }
      
      // Download completed
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
        onError('Download failed: ${e.toString()}');
      }
      
      // Remove the cancel token
      _cancelTokens.values.forEach((token) {
        if (token == cancelToken) {
          final id = _cancelTokens.entries.firstWhere((entry) => entry.value == token).key;
          _cancelTokens.remove(id);
        }
      });
      
      rethrow;
    }
  }
  
  Future<void> cancelDownload(String id) async {
    // Cancel the download if it's in progress
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Download canceled by user');
      _cancelTokens.remove(id);
    }
    
    // Try to delete the partial file
    try {
      final downloadManager = DownloadManager(); // This is not ideal, should be injected
      final download = downloadManager.downloads.firstWhere((item) => item.id == id);
      if (download.localPath != null) {
        final file = File(download.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      // Ignore errors when trying to delete the file
      print('Error deleting partial file: $e');
    }
  }
}
