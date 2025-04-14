import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uni_links/uni_links.dart';
import '../models/download_model.dart';
import '../utils/file_utils.dart';
import 'download_service.dart';

class DownloadDetectorService {
  static final DownloadDetectorService _instance = DownloadDetectorService._internal();
  factory DownloadDetectorService() => _instance;

  DownloadDetectorService._internal();

  // Services
  final DownloadService _downloadService = DownloadService();
  final DownloadManager _downloadManager = DownloadManager();

  // Stream controllers
  final StreamController<String> _detectedLinksController = StreamController<String>.broadcast();
  Stream<String> get detectedLinks => _detectedLinksController.stream;

  // Subscription for uni_links
  StreamSubscription? _uriLinkSubscription;

  // Timer for clipboard checking
  Timer? _clipboardCheckTimer;
  String? _lastClipboardText;

  // List of known download file extensions
  final List<String> _downloadExtensions = [
    '.zip', '.rar', '.7z', '.tar', '.gz', '.pdf', '.doc', '.docx', '.xls',
    '.xlsx', '.ppt', '.pptx', '.mp3', '.mp4', '.avi', '.mov', '.flv', '.wmv',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif', '.tiff', '.exe', '.msi',
    '.apk', '.dmg', '.iso', '.csv', '.txt', '.rtf', '.html', '.htm', '.xml',
    '.json', '.js', '.css', '.py', '.java', '.c', '.cpp', '.h', '.php', '.rb'
  ];

  // List of known download domains
  final List<String> _downloadDomains = [
    'download.', 'dl.', 'cdn.', 'media.', 'files.', 'storage.',
    'drive.google.com', 'docs.google.com', 'dropbox.com', 'onedrive.live.com',
    'github.com', 'gitlab.com', 'bitbucket.org', 'sourceforge.net',
    'mediafire.com', 'mega.nz', 'box.com', 'wetransfer.com', 'sendspace.com',
    'zippyshare.com', 'rapidgator.net', 'uploaded.net', 'filefactory.com',
    'workupload.com', 'filehosting.org', 'uploadfiles.io', 'filedropper.com'
  ];

  // Initialize the service
  Future<void> initialize() async {
    // Initialize clipboard checking
    _startClipboardChecking();

    // Initialize uni_links for handling deep links
    _initUniLinks();

    debugPrint('DownloadDetectorService initialized');
  }

  // Start clipboard checking
  void _startClipboardChecking() {
    // Check clipboard every 2 seconds
    _clipboardCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkClipboard();
    });

    // Initial check
    _checkClipboard();
  }

  // Check clipboard for download links
  Future<void> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;

      // Skip if clipboard is empty or unchanged
      if (text == null || text.isEmpty || text == _lastClipboardText) {
        return;
      }

      // Update last clipboard text
      _lastClipboardText = text;

      // Check if the text is a URL
      if (Uri.tryParse(text)?.hasScheme ?? false) {
        // Check if this is a download link
        if (_isDownloadLink(text)) {
          _detectedLinksController.add(text);
        }
      }
    } catch (e) {
      debugPrint('Error checking clipboard: $e');
    }
  }

  // Initialize uni_links for handling deep links
  Future<void> _initUniLinks() async {
    // Handle initial URI if the app was started by a link
    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } on PlatformException {
      debugPrint('Failed to get initial URI');
    }

    // Listen for URI changes
    _uriLinkSubscription = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleUri(uri);
      }
    }, onError: (error) {
      debugPrint('URI link error: $error');
    });
  }

  // Handle URI from deep links
  void _handleUri(Uri uri) {
    final url = uri.toString();

    // Check if this is a download link
    if (_isDownloadLink(url)) {
      _detectedLinksController.add(url);
    }
  }

  // Check if a URL is a download link
  bool _isDownloadLink(String url) {
    try {
      final uri = Uri.parse(url);

      // Always consider it a download link if it has a valid URL
      // This makes the feature more aggressive but ensures we don't miss downloads
      return true;

      /* The following code is more restrictive but can be uncommented if needed
      // Check if the URL has a file extension that indicates a download
      final path = uri.path.toLowerCase();
      if (_downloadExtensions.any((ext) => path.endsWith(ext))) {
        return true;
      }

      // Check if the URL contains download-related keywords
      if (path.contains('/download/') ||
          path.contains('/downloads/') ||
          path.contains('/get/') ||
          path.contains('/file/') ||
          uri.queryParameters.containsKey('download') ||
          uri.queryParameters.containsKey('dl')) {
        return true;
      }

      // Check if the domain is a known download domain
      final host = uri.host.toLowerCase();
      if (_downloadDomains.any((domain) => host.contains(domain))) {
        return true;
      }

      return false;
      */
    } catch (e) {
      return false;
    }
  }

  // Start a download from a detected link
  Future<DownloadItem> startDetectedDownload(String url) async {
    try {
      // Get file info
      final fileInfo = await _downloadService.getFileInfo(url);
      final fileName = fileInfo['fileName'] as String? ?? 'Unknown file';
      final contentType = fileInfo['contentType'] as String?;
      final contentLength = fileInfo['contentLength'] as String?;

      // Create a download item
      final downloadItem = DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        fileType: FileUtils.getFileTypeFromMime(contentType ?? '') ?? '',
        fileSize: contentLength != null ? double.parse(contentLength) / (1024 * 1024) : 0.0,
        url: url,
        status: DownloadStatus.pending,
      );

      // Add to download manager
      _downloadManager.addDownload(downloadItem);

      // Start the download
      final result = await _downloadService.startDownload(
        url: url,
        downloadLocation: _downloadManager.downloadLocation,
        onProgress: (updatedItem) {
          _downloadManager.updateDownloadProgress(
            downloadItem.id,
            updatedItem.progress,
            updatedItem.speed,
            updatedItem.remainingTime,
          );
        },
        onComplete: (completedItem) {
          _downloadManager.completeDownload(downloadItem.id);
        },
        onError: (error) {
          _downloadManager.failDownload(downloadItem.id);
        },
      );

      debugPrint('Download started: $fileName');
      return result;
    } catch (e) {
      debugPrint('Error starting download: $e');

      // Create a failed download item
      final failedItem = DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: FileUtils.getFileNameFromUrl(url),
        fileType: '',
        fileSize: 0.0,
        url: url,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );

      return failedItem;
    }
  }

  // Dispose resources
  void dispose() {
    _uriLinkSubscription?.cancel();
    _clipboardCheckTimer?.cancel();
    _detectedLinksController.close();
  }
}
