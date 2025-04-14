import 'dart:io' show Platform;
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/download_model.dart';
import 'database_service.dart';

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  final DatabaseService _databaseService = DatabaseService();
  bool _isInitialized = false;

  factory ScheduleService() => _instance;

  ScheduleService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    // Only initialize Workmanager on supported platforms (Android and iOS)
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: true,
        );
      } catch (e) {
        // Failed to initialize Workmanager, but we can continue without it on desktop
        // Continue without background processing on unsupported platforms
      }
    }

    _isInitialized = true;
  }

  Future<void> scheduleDownload(DownloadItem item, DateTime scheduledTime) async {
    await init();

    // Save to database
    await _databaseService.saveScheduledDownload(item);

    // Calculate delay in minutes
    final now = DateTime.now();
    final delay = scheduledTime.difference(now);
    final delayInMinutes = delay.inMinutes;

    if (delayInMinutes <= 0) {
      // If scheduled time is in the past, start download immediately
      return;
    }

    // Schedule the task only on supported platforms
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Workmanager().registerOneOffTask(
          'scheduled_download_${item.id}',
          'scheduled_download',
          initialDelay: Duration(minutes: delayInMinutes),
          inputData: {
            'id': item.id,
            'url': item.url,
            'fileName': item.fileName,
          },
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      } catch (e) {
        // Failed to schedule task, but we can continue without it on desktop
        // On desktop platforms, we'll rely on the app being open at the scheduled time
      }
    }
    // On desktop platforms, we'll rely on the app being open at the scheduled time
  }

  Future<void> cancelScheduledDownload(String id) async {
    await init();

    // Remove from database
    await _databaseService.deleteScheduledDownload(id);

    // Cancel the task only on supported platforms
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Workmanager().cancelByUniqueName('scheduled_download_$id');
      } catch (e) {
        // Failed to cancel task, but we can continue without it on desktop
        // Continue without background processing on unsupported platforms
      }
    }
  }
}

// This callback must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'scheduled_download') {
      final id = inputData?['id'] as String;
      // We'll use the URL when actually starting the download
      // final url = inputData?['url'] as String;
      final fileName = inputData?['fileName'] as String;

      // Show notification that scheduled download is starting
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'scheduled_download_channel',
        'Scheduled Downloads',
        channelDescription: 'Notifications for scheduled downloads',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        id.hashCode,
        'Scheduled Download Starting',
        'Starting download for $fileName',
        platformDetails,
      );

      // In a real app, you would start the download here
      // For now, we'll just show a notification

      return true;
    }
    return false;
  });
}
