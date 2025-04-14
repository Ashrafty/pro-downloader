import 'package:fluent_ui/fluent_ui.dart';
import 'dart:io' show Platform;
import '../models/download_model.dart';
import '../utils/file_utils.dart';

class DownloadItemWidget extends StatelessWidget {
  final DownloadItem download;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;

  const DownloadItemWidget({
    super.key,
    required this.download,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.onOpen,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we should enable double-tap (only for completed downloads on desktop)
    final bool enableDoubleTap = download.status == DownloadStatus.completed &&
                               download.localPath != null &&
                               onOpen != null &&
                               !_isRunningOnMobile();

    // Wrap with GestureDetector for double-tap support
    return GestureDetector(
      onDoubleTap: enableDoubleTap ? onOpen : null,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Icon(
                  FileUtils.getFileIcon(download.fileType),
                  size: 24,
                  color: FileUtils.getFileColor(download.fileType),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.fileName,
                        style: FluentTheme.of(context).typography.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FileUtils.formatFileSize(download.fileSize),
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: _buildActionButtons(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, // Make the progress bar take full width
              child: ProgressBar(
                value: download.progress * 100,
                backgroundColor: const Color.fromARGB(51, 128, 128, 128),
                activeColor: _getProgressColor(download.status),
                // Make the progress bar taller on desktop
                strokeWidth: _isRunningOnMobile() ? 6.0 : 10.0, // Thicker progress bar on desktop
              ),
            ),
            const SizedBox(height: 8),
            _buildBottomRow(context),
          ],
        ),
      ),
    ));

  }

  Widget _buildBottomRow(BuildContext context) {
    // For completed downloads, show completion time and open button
    if (download.status == DownloadStatus.completed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Completed ${download.formattedDuration} ago',
            style: FluentTheme.of(context).typography.caption,
          ),
          if (download.localPath != null && onOpen != null)
            Button(
              onPressed: onOpen,
              child: const Text('Open'),
            ),
        ],
      );
    }

    // For failed downloads, show retry button
    if (download.status == DownloadStatus.failed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Download failed',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: Colors.red,
            ),
          ),
          if (onRetry != null)
            Button(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      );
    }

    // For queued downloads
    if (download.status == DownloadStatus.queued) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Queued - Waiting to start',
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      );
    }

    // For active downloads, show speed and remaining time
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${download.speed} MB/s',
          style: FluentTheme.of(context).typography.caption,
        ),
        Text(
          download.remainingTime,
          style: FluentTheme.of(context).typography.caption,
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons() {
    final List<Widget> buttons = [];

    // Add appropriate action buttons based on status
    switch (download.status) {
      case DownloadStatus.downloading:
        buttons.add(IconButton(
          icon: const Icon(FluentIcons.pause),
          onPressed: onPause,
        ));
        buttons.add(IconButton(
          icon: const Icon(FluentIcons.cancel),
          onPressed: onCancel,
        ));
        break;

      case DownloadStatus.paused:
        buttons.add(IconButton(
          icon: const Icon(FluentIcons.play),
          onPressed: onResume,
        ));
        buttons.add(IconButton(
          icon: const Icon(FluentIcons.cancel),
          onPressed: onCancel,
        ));
        break;

      case DownloadStatus.queued:
        buttons.add(IconButton(
          icon: const Icon(FluentIcons.cancel),
          onPressed: onCancel,
        ));
        break;

      case DownloadStatus.completed:
        if (download.localPath != null && onOpen != null) {
          buttons.add(IconButton(
            icon: const Icon(FluentIcons.open_file),
            onPressed: onOpen,
          ));
        }
        break;

      case DownloadStatus.failed:
        if (onRetry != null) {
          buttons.add(IconButton(
            icon: const Icon(FluentIcons.refresh),
            onPressed: onRetry,
          ));
        }
        buttons.add(IconButton(
          icon: const Icon(FluentIcons.cancel),
          onPressed: onCancel,
        ));
        break;

      default:
        buttons.add(IconButton(
          icon: const Icon(FluentIcons.cancel),
          onPressed: onCancel,
        ));
    }

    return buttons;
  }

  Color _getProgressColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const Color(0xFF0066CC); // Blue accent color
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.pending:
        return Colors.grey;
      case DownloadStatus.queued:
        return const Color(0xFFFFC107); // Amber
      case DownloadStatus.canceled:
        return Colors.grey;
    }
  }

  // Helper method to check if running on mobile
  bool _isRunningOnMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }
}
