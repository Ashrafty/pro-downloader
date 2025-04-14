import 'package:flutter/material.dart';
import '../models/download_model.dart';
import '../utils/file_utils.dart';

class MobileDownloadItem extends StatelessWidget {
  final DownloadItem download;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;

  const MobileDownloadItem({
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FileUtils.getMaterialFileIcon(download.fileType),
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
                        style: Theme.of(context).textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FileUtils.formatFileSize(download.fileSize),
                        style: Theme.of(context).textTheme.bodySmall,
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
            LinearProgressIndicator(
              value: download.progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(download.status)),
            ),
            const SizedBox(height: 8),
            _buildBottomRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    // For completed downloads, show completion time and open button
    if (download.status == DownloadStatus.completed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Completed ${download.formattedDuration} ago',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (download.localPath != null && onOpen != null)
            TextButton(
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red,
            ),
          ),
          if (onRetry != null)
            TextButton(
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
            style: Theme.of(context).textTheme.bodySmall,
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
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          download.remainingTime,
          style: Theme.of(context).textTheme.bodySmall,
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
          icon: const Icon(Icons.pause),
          onPressed: onPause,
          color: Colors.grey[700],
          iconSize: 20,
        ));
        buttons.add(IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancel,
          color: Colors.grey[700],
          iconSize: 20,
        ));
        break;

      case DownloadStatus.paused:
        buttons.add(IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: onResume,
          color: Colors.grey[700],
          iconSize: 20,
        ));
        buttons.add(IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancel,
          color: Colors.grey[700],
          iconSize: 20,
        ));
        break;

      case DownloadStatus.queued:
        buttons.add(IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancel,
          color: Colors.grey[700],
          iconSize: 20,
        ));
        break;

      case DownloadStatus.completed:
        if (download.localPath != null && onOpen != null) {
          buttons.add(IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpen,
            color: Colors.grey[700],
            iconSize: 20,
          ));
        }
        break;

      case DownloadStatus.failed:
        if (onRetry != null) {
          buttons.add(IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRetry,
            color: Colors.grey[700],
            iconSize: 20,
          ));
        }
        buttons.add(IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancel,
          color: Colors.grey[700],
          iconSize: 20,
        ));
        break;

      default:
        buttons.add(IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancel,
          color: Colors.grey[700],
          iconSize: 20,
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
}
