import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/download_model.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';
import 'update_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  String _appVersion = '';
  String _buildNumber = '';
  bool _checkingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdates = true;
    });

    try {
      final updateService = Provider.of<UpdateService>(context, listen: false);
      final updateInfo = await updateService.checkForUpdates(force: true);

      if (updateInfo != null) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UpdateScreen(
                updateInfo: updateInfo,
                forceUpdate: false,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Updates Available'),
              content: const Text('You are already using the latest version of the app.'),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to check for updates: $e'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _checkingForUpdates = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    // In a real app, you would load settings from the database
    // For now, we'll use the values from the DownloadManager
  }

  Future<void> _selectDownloadLocation() async {
    final downloadManager = Provider.of<DownloadManager>(context, listen: false);

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      downloadManager.setDownloadLocation(selectedDirectory);
      await _databaseService.saveSetting('downloadLocation', selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadManager = Provider.of<DownloadManager>(context);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
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
                  'Download Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  icon: Icons.folder,
                  title: 'Download Location',
                  subtitle: downloadManager.downloadLocation,
                  trailing: TextButton(
                    onPressed: _selectDownloadLocation,
                    child: const Text('Change'),
                  ),
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.speed,
                  title: 'Multi-thread Download',
                  subtitle: 'Download files using multiple connections',
                  trailing: Switch(
                    value: downloadManager.isMultiThreadEnabled,
                    onChanged: (_) {
                      downloadManager.toggleMultiThread();
                      _databaseService.saveSetting(
                        'multiThreadEnabled',
                        downloadManager.isMultiThreadEnabled.toString(),
                      );
                    },
                  ),
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.data_usage,
                  title: 'Bandwidth Limit',
                  subtitle: 'Limit download speed',
                  trailing: DropdownButton<String>(
                    value: downloadManager.bandwidthLimit,
                    onChanged: (value) {
                      if (value != null) {
                        downloadManager.setBandwidthLimit(value);
                        _databaseService.saveSetting('bandwidthLimit', value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'No Limit',
                        child: Text('No Limit'),
                      ),
                      DropdownMenuItem(
                        value: '512 KB/s',
                        child: Text('512 KB/s'),
                      ),
                      DropdownMenuItem(
                        value: '1 MB/s',
                        child: Text('1 MB/s'),
                      ),
                      DropdownMenuItem(
                        value: '2 MB/s',
                        child: Text('2 MB/s'),
                      ),
                      DropdownMenuItem(
                        value: '5 MB/s',
                        child: Text('5 MB/s'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
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
                  'Queue Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  icon: Icons.queue,
                  title: 'Maximum Concurrent Downloads',
                  subtitle: 'Number of downloads to run at the same time',
                  trailing: DropdownButton<int>(
                    value: downloadManager.maxConcurrentDownloads,
                    onChanged: (value) {
                      if (value != null) {
                        downloadManager.setMaxConcurrentDownloads(value);
                        _databaseService.saveSetting(
                          'maxConcurrentDownloads',
                          value.toString(),
                        );
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text('1'),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('2'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('3'),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text('5'),
                      ),
                      DropdownMenuItem(
                        value: 10,
                        child: Text('10'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.network_cell,
                  title: 'Pause on Mobile Data',
                  subtitle: 'Automatically pause downloads when on mobile data',
                  trailing: Switch(
                    value: downloadManager.pauseOnMobileData,
                    onChanged: (_) {
                      downloadManager.togglePauseOnMobileData();
                      _databaseService.saveSetting(
                        'pauseOnMobileData',
                        downloadManager.pauseOnMobileData.toString(),
                      );
                    },
                  ),
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.battery_alert,
                  title: 'Pause on Low Battery',
                  subtitle: 'Automatically pause downloads when battery is low',
                  trailing: Switch(
                    value: downloadManager.pauseOnLowBattery,
                    onChanged: (_) {
                      downloadManager.togglePauseOnLowBattery();
                      _databaseService.saveSetting(
                        'pauseOnLowBattery',
                        downloadManager.pauseOnLowBattery.toString(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
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
                  'Behavior Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  icon: Icons.refresh,
                  title: 'Auto-retry on Failure',
                  subtitle: 'Automatically retry failed downloads',
                  trailing: Switch(
                    value: downloadManager.autoRetryOnFailure,
                    onChanged: (_) {
                      downloadManager.toggleAutoRetryOnFailure();
                      _databaseService.saveSetting(
                        'autoRetryOnFailure',
                        downloadManager.autoRetryOnFailure.toString(),
                      );
                    },
                  ),
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.repeat,
                  title: 'Maximum Retry Count',
                  subtitle: 'Number of times to retry a failed download',
                  trailing: DropdownButton<int>(
                    value: downloadManager.maxRetryCount,
                    onChanged: (value) {
                      if (value != null) {
                        downloadManager.setMaxRetryCount(value);
                        _databaseService.saveSetting(
                          'maxRetryCount',
                          value.toString(),
                        );
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text('1'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('3'),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text('5'),
                      ),
                      DropdownMenuItem(
                        value: 10,
                        child: Text('10'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.notifications,
                  title: 'Notify on Complete',
                  subtitle: 'Show notification when download completes',
                  trailing: Switch(
                    value: downloadManager.notifyOnComplete,
                    onChanged: (_) {
                      downloadManager.toggleNotifyOnComplete();
                      _databaseService.saveSetting(
                        'notifyOnComplete',
                        downloadManager.notifyOnComplete.toString(),
                      );
                    },
                  ),
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.open_in_new,
                  title: 'Auto-open Completed Downloads',
                  subtitle: 'Automatically open files after download',
                  trailing: Switch(
                    value: downloadManager.autoOpenCompleted,
                    onChanged: (_) {
                      downloadManager.toggleAutoOpenCompleted();
                      _databaseService.saveSetting(
                        'autoOpenCompleted',
                        downloadManager.autoOpenCompleted.toString(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
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
                  'About',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  icon: Icons.info,
                  title: 'Version',
                  subtitle: '$_appVersion (Build $_buildNumber)',
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.update,
                  title: 'Check for Updates',
                  subtitle: 'Check if a new version is available',
                  trailing: _checkingForUpdates
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                  onTap: _checkingForUpdates ? null : _checkForUpdates,
                ),
                const Divider(),
                _buildSettingItem(
                  context,
                  icon: Icons.code,
                  title: 'Source Code',
                  subtitle: 'View on GitHub',
                  onTap: () {
                    // Open GitHub repository
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0066CC)),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
