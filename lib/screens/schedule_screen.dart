import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../models/download_model.dart';
import '../utils/file_utils.dart';
import '../services/schedule_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _urlController = TextEditingController();
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 1));
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    _scheduleService.init();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledTime),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _scheduledTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _scheduleDownload() {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final downloadManager = Provider.of<DownloadManager>(context, listen: false);

    // Create a download item
    final item = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: FileUtils.getFileNameFromUrl(_urlController.text),
      fileType: path.extension(_urlController.text).replaceAll('.', ''),
      fileSize: 0.0, // Will be updated when download starts
      url: _urlController.text,
      status: DownloadStatus.pending,
      isScheduled: true,
      scheduledTime: _scheduledTime,
    );

    // Schedule the download
    downloadManager.scheduleDownload(item, _scheduledTime);
    _scheduleService.scheduleDownload(item, _scheduledTime);

    // Clear the input
    _urlController.clear();

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download scheduled for ${DateFormat('MMM dd, yyyy HH:mm').format(_scheduledTime)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadManager = Provider.of<DownloadManager>(context);
    final scheduledDownloads = downloadManager.scheduledDownloads;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule a Download',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'Enter the URL to download',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDateTime(context),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat('MMM dd, yyyy HH:mm').format(_scheduledTime)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _scheduleDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066CC),
                        ),
                        child: const Text('Schedule'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Scheduled Downloads',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: scheduledDownloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No scheduled downloads',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Schedule downloads to start at a specific time',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: scheduledDownloads.length,
                  itemBuilder: (context, index) {
                    final item = scheduledDownloads[index];
                    return _buildScheduledItem(context, item, downloadManager);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScheduledItem(BuildContext context, DownloadItem item, DownloadManager downloadManager) {
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
              'Scheduled for ${item.formattedScheduledTime}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              item.url,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                downloadManager.startScheduledDownload(item.id);
                _scheduleService.cancelScheduledDownload(item.id);
              },
              tooltip: 'Start now',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                downloadManager.removeScheduledDownload(item.id);
                _scheduleService.cancelScheduledDownload(item.id);
              },
              tooltip: 'Remove',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
