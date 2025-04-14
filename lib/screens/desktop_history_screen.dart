import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_model.dart';
import '../utils/file_utils.dart';

class DesktopHistoryScreen extends StatelessWidget {
  const DesktopHistoryScreen({super.key});

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
              FluentIcons.history,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No download history',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed downloads will appear here',
              style: FluentTheme.of(context).typography.body,
            ),
          ],
        ),
      );
    }
    
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Download History'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.delete),
              label: const Text('Clear History'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('Clear History'),
                    content: const Text('Are you sure you want to clear your download history?'),
                    actions: [
                      Button(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      FilledButton(
                        child: const Text('Clear'),
                        onPressed: () {
                          downloadManager.clearHistory();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      content: ListView.builder(
        itemCount: history.length,
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, index) {
          final item = history[index];
          return _buildHistoryItem(context, item, downloadManager);
        },
      ),
    );
  }
  
  Widget _buildHistoryItem(BuildContext context, DownloadItem item, DownloadManager downloadManager) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              FileUtils.getFileIcon(item.fileType),
              size: 32,
              color: FileUtils.getFileColor(item.fileType),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    style: FluentTheme.of(context).typography.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FileUtils.formatFileSize(item.fileSize),
                    style: FluentTheme.of(context).typography.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Downloaded on ${item.formattedEndTime}',
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.localPath != null && File(item.localPath!).existsSync())
                  IconButton(
                    icon: const Icon(FluentIcons.open_file),
                    onPressed: () async {
                      final file = File(item.localPath!);
                      if (await file.exists()) {
                        final uri = Uri.file(file.path);
                        if (!await launchUrl(uri)) {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => ContentDialog(
                                title: const Text('Error'),
                                content: const Text('Could not open file'),
                                actions: [
                                  Button(
                                    child: const Text('OK'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () {
                    downloadManager.removeFromHistory(item.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
