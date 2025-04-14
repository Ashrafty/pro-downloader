import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/download_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  factory NotificationService() => _instance;

  NotificationService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      linux: initializationSettingsLinux,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
    // In a real app, you would navigate to the download or perform an action
    // based on the payload
  }

  Future<void> showDownloadStartedNotification(DownloadItem item) async {
    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Notifications for downloads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: false,
      playSound: false,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.low,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      item.id.hashCode,
      'Download Started',
      'Downloading ${item.fileName}',
      platformDetails,
      payload: item.id,
    );
  }

  Future<void> showDownloadProgressNotification(DownloadItem item) async {
    await init();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Notifications for downloads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (item.progress * 100).toInt(),
      ongoing: true,
      playSound: false,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.low,
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: 'cancel',
          label: 'Cancel',
        ),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      item.id.hashCode,
      'Downloading ${item.fileName}',
      '${(item.progress * 100).toInt()}% - ${item.remainingTime}',
      platformDetails,
      payload: item.id,
    );
  }

  Future<void> showDownloadCompletedNotification(DownloadItem item) async {
    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Notifications for downloads',
      importance: Importance.high,
      priority: Priority.high,
      showProgress: false,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      item.id.hashCode,
      'Download Complete',
      '${item.fileName} has been downloaded',
      platformDetails,
      payload: item.id,
    );
  }

  Future<void> showDownloadFailedNotification(DownloadItem item) async {
    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Notifications for downloads',
      importance: Importance.high,
      priority: Priority.high,
      showProgress: false,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      item.id.hashCode,
      'Download Failed',
      'Failed to download ${item.fileName}',
      platformDetails,
      payload: item.id,
    );
  }

  Future<void> cancelNotification(DownloadItem item) async {
    await _notificationsPlugin.cancel(item.id.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
