import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_model.dart';
import '../utils/file_utils.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadManager = Provider.of<DownloadManager>(context);
    final history = downloadManager.history;

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No download history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed downloads will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Download History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear History'),
                      content: const Text('Are you sure you want to clear your download history?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            downloadManager.clearHistory();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear History'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return _buildHistoryItem(context, item, downloadManager);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, DownloadItem item, DownloadManager downloadManager) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(
          FileUtils.getMaterialFileIcon(item.fileType),
          color: FileUtils.getFileColor(item.fileType),
        ),
        title: Text(
          item.fileName,
          style: Theme.of(context).textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              FileUtils.formatFileSize(item.fileSize),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Downloaded on ${item.formattedEndTime}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.localPath != null && File(item.localPath!).existsSync())
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                  final file = File(item.localPath!);
                  if (await file.exists()) {
                    if (Platform.isAndroid || Platform.isIOS) {
                      final uri = Uri.file(file.path);
                      if (!await launchUrl(uri)) {
                        // Show error
                      }
                    } else {
                      // For desktop platforms
                      final uri = Uri.file(file.path);
                      if (!await launchUrl(uri)) {
                        // Show error
                      }
                    }
                  }
                },
                tooltip: 'Open file',
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                downloadManager.removeFromHistory(item.id);
              },
              tooltip: 'Remove from history',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
