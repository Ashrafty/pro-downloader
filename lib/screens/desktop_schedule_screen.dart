import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/download_model.dart';
import '../utils/file_utils.dart';
import '../services/schedule_service.dart';

class DesktopScheduleScreen extends StatefulWidget {
  const DesktopScheduleScreen({super.key});

  @override
  State<DesktopScheduleScreen> createState() => _DesktopScheduleScreenState();
}

class _DesktopScheduleScreenState extends State<DesktopScheduleScreen> {
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
    // For Fluent UI, we'll use a simple dialog to pick date
    final yearController = TextEditingController(text: _scheduledTime.year.toString());
    final monthController = TextEditingController(text: _scheduledTime.month.toString());
    final dayController = TextEditingController(text: _scheduledTime.day.toString());

    final dateResult = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Select Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter date'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    placeholder: 'Year',
                    controller: yearController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    placeholder: 'Month (1-12)',
                    controller: monthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    placeholder: 'Day (1-31)',
                    controller: dayController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          Button(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    DateTime? result;
    if (dateResult == true) {
      // Parse the date
      int year = int.tryParse(yearController.text) ?? _scheduledTime.year;
      int month = int.tryParse(monthController.text) ?? _scheduledTime.month;
      int day = int.tryParse(dayController.text) ?? _scheduledTime.day;

      // Validate the values
      year = year.clamp(DateTime.now().year, DateTime.now().year + 10);
      month = month.clamp(1, 12);
      day = day.clamp(1, 31);

      try {
        result = DateTime(year, month, day);
      } catch (e) {
        // Invalid date, use current date
        result = DateTime.now();
      }
    }

    if (result != null && mounted) {
      // For Fluent UI, we'll use a simple dialog to pick time
      final hourController = TextEditingController(text: _scheduledTime.hour.toString());
      final minuteController = TextEditingController(text: _scheduledTime.minute.toString());

      final timeResult = await showDialog<bool>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Select Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter time (24-hour format)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      placeholder: 'Hour (0-23)',
                      controller: hourController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextBox(
                      placeholder: 'Minute (0-59)',
                      controller: minuteController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            FilledButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (timeResult == true && mounted) {
        // Parse the hour and minute
        int hour = int.tryParse(hourController.text) ?? _scheduledTime.hour;
        int minute = int.tryParse(minuteController.text) ?? _scheduledTime.minute;

        // Validate the values
        hour = hour.clamp(0, 23);
        minute = minute.clamp(0, 59);

        setState(() {
          _scheduledTime = DateTime(
            result!.year,
            result.month,
            result.day,
            hour,
            minute,
          );
        });
      }
    }
  }

  void _scheduleDownload() {
    if (_urlController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Error'),
          content: const Text('Please enter a URL'),
          actions: [
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final downloadManager = Provider.of<DownloadManager>(context, listen: false);

    // Create a download item
    final item = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: FileUtils.getFileNameFromUrl(_urlController.text),
      fileType: FileUtils.getFileTypeFromMime('') ?? '',
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
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: Text('Download scheduled for ${DateFormat('MMM dd, yyyy HH:mm').format(_scheduledTime)}'),
          severity: InfoBarSeverity.success,
          onClose: close,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadManager = Provider.of<DownloadManager>(context);
    final scheduledDownloads = downloadManager.scheduledDownloads;

    return ScaffoldPage(
      header: const PageHeader(title: Text('Schedule Downloads')),
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule a Download',
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    const SizedBox(height: 16),
                    TextBox(
                      controller: _urlController,
                      placeholder: 'Enter the URL to download',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Button(
                            onPressed: () => _selectDateTime(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(FluentIcons.calendar),
                                const SizedBox(width: 8),
                                Text(DateFormat('MMM dd, yyyy HH:mm').format(_scheduledTime)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: _scheduleDownload,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.clock),
                              SizedBox(width: 8),
                              Text('Schedule'),
                            ],
                          ),
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
                  style: FluentTheme.of(context).typography.subtitle,
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
                          FluentIcons.calendar,
                          size: 64,
                          color: Colors.grey.withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No scheduled downloads',
                          style: FluentTheme.of(context).typography.subtitle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Schedule downloads to start at a specific time',
                          style: FluentTheme.of(context).typography.body,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: scheduledDownloads.length,
                    itemBuilder: (context, index) {
                      final item = scheduledDownloads[index];
                      return _buildScheduledItem(context, item, downloadManager);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledItem(BuildContext context, DownloadItem item, DownloadManager downloadManager) {
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
                    'Scheduled for ${item.formattedScheduledTime}',
                    style: FluentTheme.of(context).typography.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.url,
                    style: FluentTheme.of(context).typography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.play),
                  onPressed: () {
                    downloadManager.startScheduledDownload(item.id);
                    _scheduleService.cancelScheduledDownload(item.id);
                    displayInfoBar(
                      context,
                      builder: (context, close) {
                        return InfoBar(
                          title: const Text('Download started'),
                          severity: InfoBarSeverity.success,
                          onClose: close,
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () {
                    downloadManager.removeScheduledDownload(item.id);
                    _scheduleService.cancelScheduledDownload(item.id);
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
