import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_model.dart';
import '../services/video_extraction_service.dart';
import '../services/download_service.dart';

class DesktopSocialMediaScreen extends StatefulWidget {
  const DesktopSocialMediaScreen({super.key});

  @override
  State<DesktopSocialMediaScreen> createState() => _DesktopSocialMediaScreenState();
}

class _DesktopSocialMediaScreenState extends State<DesktopSocialMediaScreen> {
  final TextEditingController _urlController = TextEditingController();
  final VideoExtractionService _extractionService = VideoExtractionService();
  final DownloadService _downloadService = DownloadService();

  VideoInfo? _videoInfo;
  VideoQuality? _selectedQuality;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _extractVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _videoInfo = null;
      _selectedQuality = null;
    });

    try {
      final videoInfo = await _extractionService.extractVideoInfo(url);

      setState(() {
        _videoInfo = videoInfo;
        if (videoInfo != null && videoInfo.qualities.isNotEmpty) {
          _selectedQuality = videoInfo.qualities.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to extract video: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadVideo() async {
    if (_videoInfo == null || _selectedQuality == null) {
      setState(() {
        _errorMessage = 'No video selected for download';
      });
      return;
    }

    final downloadManager = Provider.of<DownloadManager>(context, listen: false);

    try {
      // Create a download item
      final item = DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: '${_videoInfo!.title}.${_selectedQuality!.format}',
        fileType: _selectedQuality!.format,
        fileSize: 0.0, // Will be updated during download
        url: _selectedQuality!.url,
        status: DownloadStatus.queued,
        metadata: {
          'platform': _videoInfo!.platform,
          'quality': _selectedQuality!.label,
          'originalUrl': _videoInfo!.url,
        },
      );

      // Add to download manager
      downloadManager.addDownload(item);

      // Show notification (commented out for Linux compatibility)
      // await _notificationService.showDownloadStartedNotification(item);

      // Show success message
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text('Download started: ${_videoInfo!.title}'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
      }

      // Start the actual download
      _downloadService.startDownload(
        url: _selectedQuality!.url,
        downloadLocation: downloadManager.downloadLocation,
        onProgress: (updatedItem) {
          downloadManager.updateDownloadProgress(
            item.id,
            updatedItem.progress,
            updatedItem.speed,
            updatedItem.remainingTime,
          );

          // Update notification periodically (commented out for Linux compatibility)
          // if (updatedItem.progress > 0 && updatedItem.progress % 0.1 < 0.01) {
          //   _notificationService.showDownloadProgressNotification(updatedItem);
          // }
        },
        onComplete: (completedItem) {
          downloadManager.completeDownload(item.id);
          // _notificationService.showDownloadCompletedNotification(completedItem);

          // Auto-open if enabled
          if (downloadManager.autoOpenCompleted && completedItem.localPath != null) {
            _openFile(completedItem.localPath!);
          }
        },
        onError: (error) {
          downloadManager.failDownload(item.id);
          // _notificationService.showDownloadFailedNotification(item);

          if (mounted) {
            displayInfoBar(context, builder: (context, close) {
              return InfoBar(
                title: Text('Download failed: $error'),
                severity: InfoBarSeverity.error,
                onClose: close,
              );
            });
          }
        },
      );

      // Reset the form
      setState(() {
        _videoInfo = null;
        _selectedQuality = null;
        _urlController.clear();
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start download: ${e.toString()}';
      });
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (!await launchUrl(uri)) {
        throw Exception('Could not open file');
      }
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

  Widget _buildPlatformIcon(String platform) {
    IconData iconData;
    Color color;

    switch (platform.toLowerCase()) {
      case 'youtube':
        iconData = FluentIcons.video;
        color = const Color(0xFFFF0000); // YouTube red
        break;
      case 'facebook':
        iconData = FluentIcons.share;
        color = const Color(0xFF1877F2); // Facebook blue
        break;
      case 'twitter':
        iconData = FluentIcons.message;
        color = const Color(0xFF1DA1F2); // Twitter blue
        break;
      case 'tiktok':
        iconData = FluentIcons.video;
        color = const Color(0xFF000000); // TikTok black
        break;
      default:
        iconData = FluentIcons.video;
        color = Colors.grey;
    }

    return Icon(iconData, color: color, size: 24);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('Social Media Video Downloader')),
      content: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Download videos from YouTube, Facebook, Twitter, and TikTok',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextBox(
                            controller: _urlController,
                            placeholder: 'Paste video URL here...',
                            onSubmitted: (_) => _extractVideoInfo(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Button(
                          onPressed: _isLoading ? null : _extractVideoInfo,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: ProgressRing(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Extract Video'),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      InfoBar(
                        title: Text(_errorMessage!),
                        severity: InfoBarSeverity.error,
                        isLong: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_videoInfo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_videoInfo!.thumbnailUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _videoInfo!.thumbnailUrl,
                                width: 160,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 160,
                                    height: 90,
                                    color: Colors.grey.withAlpha(50),
                                    child: const Center(
                                      child: Icon(FluentIcons.error, size: 32),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: 160,
                              height: 90,
                              color: Colors.grey.withAlpha(50),
                              child: const Center(
                                child: Icon(FluentIcons.video, size: 32),
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _videoInfo!.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildPlatformIcon(_videoInfo!.platform),
                                    const SizedBox(width: 8),
                                    Text(
                                      _videoInfo!.platform,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Select Quality:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ComboBox<VideoQuality>(
                                  value: _selectedQuality,
                                  items: _videoInfo!.qualities.map((quality) {
                                    return ComboBoxItem<VideoQuality>(
                                      value: quality,
                                      child: Text(quality.label),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedQuality = value;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            onPressed: _downloadVideo,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.download),
                                SizedBox(width: 8),
                                Text('Download Video'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_isLoading) ...[
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 32),
                    ProgressRing(),
                    SizedBox(height: 16),
                    Text('Extracting video information...'),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.video,
                        size: 64,
                        color: Colors.grey.withAlpha(128),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Enter a social media video URL to get started',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Supported platforms: YouTube, Facebook, Twitter, TikTok',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
