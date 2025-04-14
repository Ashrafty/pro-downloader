import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_model.dart';
import '../widgets/download_item_widget.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_logo.dart';
import '../services/download_service.dart';
import '../services/chunked_download_service.dart';
import '../services/simple_download_service.dart';
import '../services/notification_service.dart';
import '../utils/file_utils.dart';
import 'mobile_home_screen.dart';
import 'desktop_history_screen.dart';
import 'desktop_schedule_screen.dart';
import 'desktop_settings_screen.dart';
import 'desktop_social_media_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _urlController = TextEditingController();

  List<NavigationPaneItem> _buildItems(BuildContext context, DownloadManager downloadManager, bool isDesktop) {
    return [
      PaneItem(
        icon: const Icon(FluentIcons.download),
        title: const Text('Downloads'),
        body: _buildDownloadsPage(context, downloadManager, isDesktop),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.video),
        title: const Text('Social Media'),
        body: const DesktopSocialMediaScreen(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.history),
        title: const Text('History'),
        body: const DesktopHistoryScreen(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.calendar),
        title: const Text('Schedule'),
        body: const DesktopScheduleScreen(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.settings),
        title: const Text('Settings'),
        body: const DesktopSettingsScreen(),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (_urlController.text.isEmpty) {
      displayInfoBar(context, builder: (context, close) {
        return InfoBar(
          title: const Text('Please enter a URL'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        );
      });
      return;
    }

    final downloadManager = Provider.of<DownloadManager>(context, listen: false);
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    final notificationService = NotificationService();

    // Step 1: Show a message that we're fetching information
    if (mounted) {
      displayInfoBar(context, builder: (context, close) {
        return InfoBar(
          title: const Text('Fetching file information...'),
          severity: InfoBarSeverity.info,
          onClose: close,
        );
      });
    }

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

      // Show notification (commented out for Linux compatibility)
      // await notificationService.showDownloadStartedNotification(tempItem);

      // Show success message
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text('Download started: ${tempItem.fileName}'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
      }

      // Clear the input field
      _urlController.clear();

      // Get the simple download service before the async gap
      final simpleDownloadService = Provider.of<SimpleDownloadService>(context, listen: false);

      // Log the download start
      debugPrint('Starting download from URL: ${tempItem.url}');

      // Start the actual download using the simple download service
      final downloadResult = await simpleDownloadService.startDownload(
        url: tempItem.url,
        downloadLocation: downloadManager.downloadLocation,
        onProgress: (updatedItem) {
          // Update the UI with progress information
          downloadManager.updateDownloadProgress(
            tempItem.id,
            updatedItem.progress,
            updatedItem.speed,
            updatedItem.remainingTime,
          );

          // Update notification periodically (every 10%)
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
            displayInfoBar(context, builder: (context, close) {
              return InfoBar(
                title: Text('Download completed: ${completedItem.fileName}'),
                severity: InfoBarSeverity.success,
                onClose: close,
              );
            });
          }

          debugPrint('Download completed: ${completedItem.fileName}');
        },
        onError: (error) {
          // Update the download status to failed
          downloadManager.failDownload(tempItem.id);

          // Show notification
          notificationService.showDownloadFailedNotification(tempItem);

          // Show error message
          if (mounted) {
            displayInfoBar(context, builder: (context, close) {
              return InfoBar(
                title: Text('Download failed: $error'),
                severity: InfoBarSeverity.error,
                onClose: close,
              );
            });
          }

          debugPrint('Download error: $error');
        },
      );

      // Handle the download result if needed
      if (downloadResult.status == DownloadStatus.failed && downloadResult.errorMessage != null) {
        // Show error message if the download failed
        if (mounted) {
          displayInfoBar(context, builder: (context, close) {
            return InfoBar(
              title: Text('Download failed: ${downloadResult.errorMessage}'),
              severity: InfoBarSeverity.error,
              onClose: close,
            );
          });
        }
      }

    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text('Error: $e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text('Could not open file: $e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadManager = Provider.of<DownloadManager>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      return const material.Material(child: MobileHomeScreen());
    } else {
      return _buildDesktopLayout(context, downloadManager, isDesktop);
    }
  }

  Widget _buildDesktopLayout(BuildContext context, DownloadManager downloadManager, bool isDesktop) {
    return NavigationView(
      appBar: NavigationAppBar(
        title: const Text('DownloadPro', style: TextStyle(fontSize: 20)),
        automaticallyImplyLeading: false,
      ),
      pane: NavigationPane(
        selected: _selectedIndex,
        onChanged: (index) => setState(() => _selectedIndex = index),
        displayMode: PaneDisplayMode.open,
        items: _buildItems(context, downloadManager, isDesktop),
        header: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const AppLogo(size: 40),
        ),
      ),
    );
  }

  Widget _buildDownloadsPage(BuildContext context, DownloadManager downloadManager, bool isDesktop) {
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    final notificationService = NotificationService();

    return ScaffoldPage(
      header: isDesktop ? const PageHeader(title: Text('Downloads')) : null,
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: _urlController,
                        placeholder: 'Paste File Link Here...',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _startDownload,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.download),
                          SizedBox(width: 8),
                          Text('Download'),
                        ],
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
                style: FluentTheme.of(context).typography.subtitle,
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
                          FluentIcons.download,
                          size: 64,
                          color: Colors.grey.withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active downloads',
                          style: FluentTheme.of(context).typography.subtitle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Paste a URL above to start downloading',
                          style: FluentTheme.of(context).typography.body,
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
                        child: DownloadItemWidget(
                          download: download,
                          onPause: () {
                            debugPrint('Pause button clicked for download: ${download.fileName}');
                            _pauseDownload(download, downloadManager, downloadService);
                          },
                          onResume: () {
                            debugPrint('Resume button clicked for download: ${download.fileName}');
                            _resumeDownload(download, downloadManager, downloadService, notificationService);
                          },
                          onCancel: () {
                            debugPrint('Cancel button clicked for download: ${download.fileName}');
                            _cancelDownload(download, downloadManager, downloadService);
                          },
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
      ),
    );
  }

  Future<void> _cancelDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService) async {
    // Get the simple download service before the async gap
    final simpleDownloadService = Provider.of<SimpleDownloadService>(context, listen: false);

    // Cancel the download
    await simpleDownloadService.cancelDownload(download.id);

    // Remove from download manager
    downloadManager.cancelDownload(download.id);

    // Log the cancel action
    debugPrint('Cancelled download: ${download.fileName}');
  }

  Future<void> _pauseDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService) async {
    // Get the simple download service
    final simpleDownloadService = Provider.of<SimpleDownloadService>(context, listen: false);

    // First update the status in the download manager
    downloadManager.pauseDownload(download.id);

    // Then pause the actual download in the service
    await simpleDownloadService.pauseDownload(download.id);

    // Log the pause action
    debugPrint('Paused download: ${download.fileName}');
  }

  Future<void> _resumeDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService, NotificationService notificationService) async {
    // Get the simple download service
    final simpleDownloadService = Provider.of<SimpleDownloadService>(context, listen: false);

    // Update the status in the download manager
    downloadManager.resumeDownload(download.id);

    // Log the resume action
    debugPrint('Resuming download: ${download.fileName}');

    // Resume the actual download in the service
    try {
      final result = await simpleDownloadService.resumeDownload(
        id: download.id,
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

      // Log the result
      debugPrint('Resume result: ${result.status}');
    } catch (e) {
      // If resume fails, try to start a new download
      debugPrint('Error resuming download: $e');
      await _retryDownload(download, downloadManager, downloadService, notificationService);
    }
  }

  Future<void> _retryDownload(DownloadItem download, DownloadManager downloadManager, DownloadService downloadService, NotificationService notificationService) async {
    // Get the simple download service before the async gap
    final simpleDownloadService = Provider.of<SimpleDownloadService>(context, listen: false);

    // Reset the download
    downloadManager.resumeDownload(download.id);

    // Log the retry action
    debugPrint('Retrying download: ${download.fileName}');

    // Start the download again
    try {
      await simpleDownloadService.startDownload(
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
          debugPrint('Retry completed: ${completedItem.fileName}');
        },
        onError: (error) {
          downloadManager.failDownload(download.id);
          notificationService.showDownloadFailedNotification(download);
          debugPrint('Retry failed: $error');
        },
      );
    } catch (e) {
      downloadManager.failDownload(download.id);
      debugPrint('Exception during retry: $e');
    }
  }


}
