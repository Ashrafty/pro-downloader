import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum DownloadStatus {
  downloading,
  paused,
  completed,
  failed,
  pending,
  queued,
  canceled
}

class DownloadItem {
  final String id;
  final String fileName;
  final String fileType;
  final double fileSize;
  final String url;
  DownloadStatus status;
  double progress;
  double speed;
  String remainingTime;
  String? localPath;
  DateTime startTime;
  DateTime? endTime;
  int retryCount;
  bool isScheduled;
  DateTime? scheduledTime;
  Map<String, dynamic>? metadata;
  String? errorMessage;

  DownloadItem({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.url,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.speed = 0.0,
    this.remainingTime = '',
    this.localPath,
    DateTime? startTime,
    this.endTime,
    this.retryCount = 0,
    this.isScheduled = false,
    this.scheduledTime,
    this.metadata,
    this.errorMessage,
  }) : startTime = startTime ?? DateTime.now();

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'url': url,
      'status': status.index,
      'progress': progress,
      'speed': speed,
      'remainingTime': remainingTime,
      'localPath': localPath,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'retryCount': retryCount,
      'isScheduled': isScheduled ? 1 : 0,
      'scheduledTime': scheduledTime?.millisecondsSinceEpoch,
      'metadata': metadata?.toString(),
      'errorMessage': errorMessage,
    };
  }

  // Create from Map
  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'],
      fileName: map['fileName'],
      fileType: map['fileType'],
      fileSize: map['fileSize'],
      url: map['url'],
      status: DownloadStatus.values[map['status']],
      progress: map['progress'],
      speed: map['speed'],
      remainingTime: map['remainingTime'],
      localPath: map['localPath'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['endTime']) : null,
      retryCount: map['retryCount'],
      isScheduled: map['isScheduled'] == 1,
      scheduledTime: map['scheduledTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['scheduledTime']) : null,
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
      errorMessage: map['errorMessage'],
    );
  }

  // Create a copy with updated fields
  DownloadItem copyWith({
    String? id,
    String? fileName,
    String? fileType,
    double? fileSize,
    String? url,
    DownloadStatus? status,
    double? progress,
    double? speed,
    String? remainingTime,
    String? localPath,
    DateTime? startTime,
    DateTime? endTime,
    int? retryCount,
    bool? isScheduled,
    DateTime? scheduledTime,
    Map<String, dynamic>? metadata,
    String? errorMessage,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      url: url ?? this.url,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      remainingTime: remainingTime ?? this.remainingTime,
      localPath: localPath ?? this.localPath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      retryCount: retryCount ?? this.retryCount,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get formattedStartTime => DateFormat('MMM dd, yyyy HH:mm').format(startTime);
  String get formattedEndTime => endTime != null ? DateFormat('MMM dd, yyyy HH:mm').format(endTime!) : '';
  String get formattedScheduledTime => scheduledTime != null ? DateFormat('MMM dd, yyyy HH:mm').format(scheduledTime!) : '';

  Duration get downloadDuration {
    if (endTime == null) {
      return DateTime.now().difference(startTime);
    }
    return endTime!.difference(startTime);
  }

  String get formattedDuration {
    final duration = downloadDuration;
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }
}

class DownloadManager extends ChangeNotifier {
  final List<DownloadItem> _downloads = [];
  final List<DownloadItem> _history = [];
  final List<DownloadItem> _scheduledDownloads = [];
  bool _isMultiThreadEnabled = true;
  String _bandwidthLimit = 'No Limit';
  String _downloadLocation = 'Downloads';
  int _maxConcurrentDownloads = 3;
  bool _pauseOnMobileData = false;
  bool _pauseOnLowBattery = false;
  bool _autoRetryOnFailure = true;
  int _maxRetryCount = 3;
  bool _notifyOnComplete = true;
  bool _autoOpenCompleted = false;

  List<DownloadItem> get downloads => _downloads;
  List<DownloadItem> get history => _history;
  List<DownloadItem> get scheduledDownloads => _scheduledDownloads;
  bool get isMultiThreadEnabled => _isMultiThreadEnabled;
  String get bandwidthLimit => _bandwidthLimit;
  String get downloadLocation => _downloadLocation;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  bool get pauseOnMobileData => _pauseOnMobileData;
  bool get pauseOnLowBattery => _pauseOnLowBattery;
  bool get autoRetryOnFailure => _autoRetryOnFailure;
  int get maxRetryCount => _maxRetryCount;
  bool get notifyOnComplete => _notifyOnComplete;
  bool get autoOpenCompleted => _autoOpenCompleted;

  // Active downloads count
  int get activeDownloadsCount => _downloads.where(
    (item) => item.status == DownloadStatus.downloading
  ).length;

  // Queue management
  bool get canStartNewDownload => activeDownloadsCount < _maxConcurrentDownloads;

  void addDownload(DownloadItem item) {
    if (canStartNewDownload) {
      item.status = DownloadStatus.downloading;
    } else {
      item.status = DownloadStatus.queued;
    }
    _downloads.add(item);
    notifyListeners();
  }

  void removeDownload(String id) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _downloads[index];
      _downloads.removeAt(index);

      // If it was completed, add to history
      if (item.status == DownloadStatus.completed) {
        _addToHistory(item);
      }

      // Start next queued download if available
      _processQueue();

      notifyListeners();
    }
  }

  void pauseDownload(String id) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      _downloads[index].status = DownloadStatus.paused;

      // Start next queued download if available
      _processQueue();

      notifyListeners();
    }
  }

  void resumeDownload(String id) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      if (canStartNewDownload) {
        _downloads[index].status = DownloadStatus.downloading;
      } else {
        _downloads[index].status = DownloadStatus.queued;
      }

      _processQueue();
      notifyListeners();
    }
  }

  void updateDownloadProgress(String id, double progress, double speed, String remainingTime) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      _downloads[index].progress = progress;
      _downloads[index].speed = speed;
      _downloads[index].remainingTime = remainingTime;
      notifyListeners();
    }
  }

  void completeDownload(String id) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _downloads[index];
      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      item.endTime = DateTime.now();

      // Add to history
      _addToHistory(item);

      // Start next queued download if available
      _processQueue();

      notifyListeners();
    }
  }

  void failDownload(String id) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _downloads[index];

      // Check if we should retry
      if (_autoRetryOnFailure && item.retryCount < _maxRetryCount) {
        item.retryCount++;
        item.status = DownloadStatus.queued;
      } else {
        item.status = DownloadStatus.failed;
        item.endTime = DateTime.now();
      }

      // Start next queued download if available
      _processQueue();

      notifyListeners();
    }
  }

  void cancelDownload(String id) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _downloads[index];
      item.status = DownloadStatus.canceled;
      item.endTime = DateTime.now();

      // Add to history
      _addToHistory(item);

      // Remove from active downloads
      _downloads.removeAt(index);

      // Start next queued download if available
      _processQueue();

      notifyListeners();
    }
  }

  void _processQueue() {
    if (!canStartNewDownload) return;

    // Find the first queued download
    final queuedIndex = _downloads.indexWhere((item) => item.status == DownloadStatus.queued);
    if (queuedIndex != -1) {
      _downloads[queuedIndex].status = DownloadStatus.downloading;
      notifyListeners();
    }
  }

  void _addToHistory(DownloadItem item) {
    // Check if already in history
    if (!_history.any((historyItem) => historyItem.id == item.id)) {
      _history.add(item);
    }
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  void removeFromHistory(String id) {
    _history.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // Schedule a download for later
  void scheduleDownload(DownloadItem item, DateTime scheduledTime) {
    item.isScheduled = true;
    item.scheduledTime = scheduledTime;
    _scheduledDownloads.add(item);
    notifyListeners();
  }

  void removeScheduledDownload(String id) {
    _scheduledDownloads.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void startScheduledDownload(String id) {
    final index = _scheduledDownloads.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _scheduledDownloads[index];
      item.isScheduled = false;
      item.scheduledTime = null;

      // Add to active downloads
      addDownload(item);

      // Remove from scheduled
      _scheduledDownloads.removeAt(index);

      notifyListeners();
    }
  }

  // Settings
  void toggleMultiThread() {
    _isMultiThreadEnabled = !_isMultiThreadEnabled;
    notifyListeners();
  }

  void setBandwidthLimit(String limit) {
    _bandwidthLimit = limit;
    notifyListeners();
  }

  void setDownloadLocation(String location) {
    _downloadLocation = location;
    notifyListeners();
  }

  void setMaxConcurrentDownloads(int count) {
    _maxConcurrentDownloads = count;
    _processQueue(); // Process queue in case we can start more downloads now
    notifyListeners();
  }

  void togglePauseOnMobileData() {
    _pauseOnMobileData = !_pauseOnMobileData;
    notifyListeners();
  }

  void togglePauseOnLowBattery() {
    _pauseOnLowBattery = !_pauseOnLowBattery;
    notifyListeners();
  }

  void toggleAutoRetryOnFailure() {
    _autoRetryOnFailure = !_autoRetryOnFailure;
    notifyListeners();
  }

  void setMaxRetryCount(int count) {
    _maxRetryCount = count;
    notifyListeners();
  }

  void toggleNotifyOnComplete() {
    _notifyOnComplete = !_notifyOnComplete;
    notifyListeners();
  }

  void toggleAutoOpenCompleted() {
    _autoOpenCompleted = !_autoOpenCompleted;
    notifyListeners();
  }


}
