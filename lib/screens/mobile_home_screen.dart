import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_model.dart';
import '../widgets/mobile_download_item.dart';
import '../services/download_service.dart';
import '../services/notification_service.dart';
import '../utils/file_utils.dart';
import 'history_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final downloadManager = Provider.of<DownloadManager>(context);
    final downloadService = Provider.of<DownloadService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getPageTitle(),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              setState(() => _selectedIndex = 3);
            },
          ),
        ],
      ),
      body: _buildPage(downloadManager, downloadService),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0066CC),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(DownloadManager downloadManager, DownloadService downloadService) {
    switch (_selectedIndex) {
      case 0:
        return _buildDownloadsPage(downloadManager);
      case 1:
        return const HistoryScreen();
      case 2:
        return const ScheduleScreen();
      case 3:
        return const SettingsScreen();
      default:
        return _buildDownloadsPage(downloadManager);
    }
  }

  Widget _buildDownloadsPage(DownloadManager downloadManager) {
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    final notificationService = NotificationService();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Paste File Link Here...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startRealDownload(downloadManager, downloadService, notificationService),
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066CC),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Active Downloads',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: downloadManager.downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active downloads',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Paste a URL above to start downloading',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: downloadManager.downloads.length,
                  itemBuilder: (context, index) {
                    final download = downloadManager.downloads[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: MobileDownloadItem(
                        download: download,
                        onPause: () => _pauseDownload(download, downloadManager, downloadService),
                        onResume: () => _resumeDownload(download, downloadManager, downloadService, notificationService),
                        onCancel: () => _cancelDownload(download, downloadManager, downloadService),
                        onOpen: download.localPath != null
                            ? () => _openFile(download.localPath!)
                            : null,
                        onRetry: download.status == DownloadStatus.failed
                            ? () => _retryDownload(download, downloadManager, downloadService, notificationService)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _startRealDownload(DownloadManager downloadManager, DownloadService downloadService, NotificationService notificationService) async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show a message that we're fetching information
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fetching file information...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Get file info before starting download
      final fileInfo = await downloadService.getFileInfo(_urlController.text);

      // Try to get filename from Content-Disposition header
      String fileName;
      if (fileInfo['contentDisposition'] != null) {
        fileName = FileUtils.getFileNameFromContentDisposition(fileInfo['contentDisposition']) ??
                  FileUtils.getFileNameFromUrl(_urlController.text);
      } else {
        fileName = FileUtils.getFileNameFromUrl(_urlController.text);
      }

      // Get file type and size
      final contentType = fileInfo['contentType'] as String?;
      final contentLength = fileInfo['contentLength'] as String?;
      final fileType = FileUtils.getFileTypeFromMime(contentType ?? '') ?? '';
      final fileSize = contentLength != null ? double.parse(contentLength) / (1024 * 1024) : 0.0;

      // Show notification that download is starting
      await notificationService.init();

      // Create a download item with the information we have
      final tempItem = DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        url: _urlController.text,
        status: DownloadStatus.pending,
      );

      // Add to download manager
      downloadManager.addDownload(tempItem);

      // Show notification
      await notificationService.showDownloadStartedNotification(tempItem);

      // Clear the input field
      _urlController.clear();

      // Show starting message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting download: ${tempItem.fileName}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Start the actual download
      final downloadResult = await downloadService.startDownload(
        url: tempItem.url,
        downloadLocation: downloadManager.downloadLocation,
        onProgress: (updatedItem) {
          downloadManager.updateDownloadProgress(
            tempItem.id,
            updatedItem.progress,
            updatedItem.speed,
            updatedItem.remainingTime,
          );

          // Update notification periodically
          if (updatedItem.progress > 0 && updatedItem.progress % 0.1 < 0.01) {
            notificationService.showDownloadProgressNotification(updatedItem);
          }
        },
        onComplete: (completedItem) {
          // Update the download status to completed
          downloadManager.completeDownload(tempItem.id);

          // Show notification
          notificationService.showDownloadCompletedNotification(completedItem);

          // Auto-open if enabled
          if (downloadManager.autoOpenCompleted && completedItem.localPath != null) {
            _openFile(completedItem.localPath!);
          }

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download completed: ${completedItem.fileName}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onError: (error) {
          // Update the download status to failed
          downloadManager.failDownload(tempItem.id);

          // Show notification
          notificationService.showDownloadFailedNotification(tempItem);

          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: $error'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );

      // Handle the download result if needed
      if (downloadResult.status == DownloadStatus.failed && downloadResult.errorMessage != null) {
        // Show error message if the download failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${downloadResult.errorMessage}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService) async {
    // Cancel the download
    await downloadService.cancelDownload(download.id);

    // Remove from download manager
    downloadManager.cancelDownload(download.id);
  }

  Future<void> _pauseDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService) async {
    // First update the status in the download manager
    downloadManager.pauseDownload(download.id);

    // Then pause the actual download in the service
    await downloadService.pauseDownload(download.id);
  }

  Future<void> _resumeDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService, NotificationService notificationService) async {
    // Update the status in the download manager
    downloadManager.resumeDownload(download.id);

    // Resume the actual download in the service
    try {
      final result = await downloadService.resumeDownload(
        id: download.id,
        downloadLocation: downloadManager.downloadLocation,
        onProgress: (updatedItem) {
          downloadManager.updateDownloadProgress(
            download.id,
            updatedItem.progress,
            updatedItem.speed,
            updatedItem.remainingTime,
          );
        },
        onComplete: (completedItem) {
          downloadManager.completeDownload(download.id);
          notificationService.showDownloadCompletedNotification(completedItem);
        },
        onError: (error) {
          downloadManager.failDownload(download.id);
          notificationService.showDownloadFailedNotification(download);
        },
      );

      // If resume failed, try to start a new download
      if (result == null) {
        await _retryDownload(download, downloadManager, downloadService, notificationService);
      }
    } catch (e) {
      // If resume fails, try to start a new download
      await _retryDownload(download, downloadManager, downloadService, notificationService);
    }
  }

  Future<void> _retryDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService, NotificationService notificationService) async {
    // Reset the download
    downloadManager.resumeDownload(download.id);

    // Start the download again
    try {
      await downloadService.startDownload(
        url: download.url,
        downloadLocation: downloadManager.downloadLocation,
        onProgress: (updatedItem) {
          downloadManager.updateDownloadProgress(
            download.id,
            updatedItem.progress,
            updatedItem.speed,
            updatedItem.remainingTime,
          );
        },
        onComplete: (completedItem) {
          downloadManager.completeDownload(download.id);
          notificationService.showDownloadCompletedNotification(completedItem);
        },
        onError: (error) {
          downloadManager.failDownload(download.id);
          notificationService.showDownloadFailedNotification(download);
        },
      );
    } catch (e) {
      downloadManager.failDownload(download.id);
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }



  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Downloads';
      case 1:
        return 'History';
      case 2:
        return 'Schedule';
      case 3:
        return 'Settings';
      default:
        return 'Downloads';
    }
  }
}
