import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_model.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';

class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen> {
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

  Future<void> _loadSettings() async {
    // In a real app, you would load settings from the database
    // For now, we'll use the values from the DownloadManager
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
          showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: const Text('Update Available'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version ${updateInfo.version} is available.'),
                  const SizedBox(height: 8),
                  Text('Current version: $_appVersion (Build $_buildNumber)'),
                  const SizedBox(height: 16),
                  const Text('What\'s new:'),
                  const SizedBox(height: 8),
                  ...updateInfo.releaseNotes.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(note)),
                      ],
                    ),
                  )),
                ],
              ),
              actions: [
                Button(
                  child: const Text('Later'),
                  onPressed: () => Navigator.pop(context),
                ),
                FilledButton(
                  child: const Text('Download Update'),
                  onPressed: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse(updateInfo.downloadUrl));
                  },
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: const Text('No Updates Available'),
              content: Text('You are already using the latest version ($_appVersion).'),
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
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to check for updates: $e'),
            actions: [
              Button(
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

    return ScaffoldPage(
      header: const PageHeader(title: Text('Settings')),
      content: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSettingsCard(
            context,
            title: 'Download Settings',
            children: [
              _buildSettingItem(
                context,
                icon: FluentIcons.folder,
                title: 'Download Location',
                subtitle: downloadManager.downloadLocation,
                trailing: Button(
                  onPressed: _selectDownloadLocation,
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.processing,
                title: 'Multi-thread Download',
                subtitle: 'Download files using multiple connections',
                trailing: ToggleSwitch(
                  checked: downloadManager.isMultiThreadEnabled,
                  onChanged: (value) {
                    downloadManager.toggleMultiThread();
                    _databaseService.saveSetting(
                      'multiThreadEnabled',
                      downloadManager.isMultiThreadEnabled.toString(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.flow,
                title: 'Bandwidth Limit',
                subtitle: 'Limit download speed',
                trailing: ComboBox<String>(
                  value: downloadManager.bandwidthLimit,
                  items: const [
                    ComboBoxItem(
                      value: 'No Limit',
                      child: Text('No Limit'),
                    ),
                    ComboBoxItem(
                      value: '512 KB/s',
                      child: Text('512 KB/s'),
                    ),
                    ComboBoxItem(
                      value: '1 MB/s',
                      child: Text('1 MB/s'),
                    ),
                    ComboBoxItem(
                      value: '2 MB/s',
                      child: Text('2 MB/s'),
                    ),
                    ComboBoxItem(
                      value: '5 MB/s',
                      child: Text('5 MB/s'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      downloadManager.setBandwidthLimit(value);
                      _databaseService.saveSetting('bandwidthLimit', value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            context,
            title: 'Queue Settings',
            children: [
              _buildSettingItem(
                context,
                icon: FluentIcons.list,
                title: 'Maximum Concurrent Downloads',
                subtitle: 'Number of downloads to run at the same time',
                trailing: ComboBox<int>(
                  value: downloadManager.maxConcurrentDownloads,
                  items: const [
                    ComboBoxItem(
                      value: 1,
                      child: Text('1'),
                    ),
                    ComboBoxItem(
                      value: 2,
                      child: Text('2'),
                    ),
                    ComboBoxItem(
                      value: 3,
                      child: Text('3'),
                    ),
                    ComboBoxItem(
                      value: 5,
                      child: Text('5'),
                    ),
                    ComboBoxItem(
                      value: 10,
                      child: Text('10'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      downloadManager.setMaxConcurrentDownloads(value);
                      _databaseService.saveSetting(
                        'maxConcurrentDownloads',
                        value.toString(),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.cell_phone,
                title: 'Pause on Mobile Data',
                subtitle: 'Automatically pause downloads when on mobile data',
                trailing: ToggleSwitch(
                  checked: downloadManager.pauseOnMobileData,
                  onChanged: (value) {
                    downloadManager.togglePauseOnMobileData();
                    _databaseService.saveSetting(
                      'pauseOnMobileData',
                      downloadManager.pauseOnMobileData.toString(),
                    );
                  },
                ),
              ),

            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            context,
            title: 'Behavior Settings',
            children: [
              _buildSettingItem(
                context,
                icon: FluentIcons.refresh,
                title: 'Auto-retry on Failure',
                subtitle: 'Automatically retry failed downloads',
                trailing: ToggleSwitch(
                  checked: downloadManager.autoRetryOnFailure,
                  onChanged: (value) {
                    downloadManager.toggleAutoRetryOnFailure();
                    _databaseService.saveSetting(
                      'autoRetryOnFailure',
                      downloadManager.autoRetryOnFailure.toString(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.sync,
                title: 'Maximum Retry Count',
                subtitle: 'Number of times to retry a failed download',
                trailing: ComboBox<int>(
                  value: downloadManager.maxRetryCount,
                  items: const [
                    ComboBoxItem(
                      value: 1,
                      child: Text('1'),
                    ),
                    ComboBoxItem(
                      value: 3,
                      child: Text('3'),
                    ),
                    ComboBoxItem(
                      value: 5,
                      child: Text('5'),
                    ),
                    ComboBoxItem(
                      value: 10,
                      child: Text('10'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      downloadManager.setMaxRetryCount(value);
                      _databaseService.saveSetting(
                        'maxRetryCount',
                        value.toString(),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.ringer,
                title: 'Notify on Complete',
                subtitle: 'Show notification when download completes',
                trailing: ToggleSwitch(
                  checked: downloadManager.notifyOnComplete,
                  onChanged: (value) {
                    downloadManager.toggleNotifyOnComplete();
                    _databaseService.saveSetting(
                      'notifyOnComplete',
                      downloadManager.notifyOnComplete.toString(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.open_file,
                title: 'Auto-open Completed Downloads',
                subtitle: 'Automatically open files after download',
                trailing: ToggleSwitch(
                  checked: downloadManager.autoOpenCompleted,
                  onChanged: (value) {
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
          const SizedBox(height: 16),
          _buildSettingsCard(
            context,
            title: 'About',
            children: [
              _buildSettingItem(
                context,
                icon: FluentIcons.info,
                title: 'Version',
                subtitle: '$_appVersion (Build $_buildNumber)',
                trailing: null,
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.sync,
                title: 'Check for Updates',
                subtitle: 'Check if a new version is available',
                trailing: _checkingForUpdates
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: ProgressRing(
                          strokeWidth: 2,
                        ),
                      )
                    : Button(
                        onPressed: _checkForUpdates,
                        child: const Text('Check Now'),
                      ),
              ),
              const SizedBox(height: 16),
              _buildSettingItem(
                context,
                icon: FluentIcons.code,
                title: 'Source Code',
                subtitle: 'View on GitHub',
                trailing: Button(
                  onPressed: () {
                    // Open GitHub repository
                  },
                  child: const Text('Open'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    Widget content = Row(
      children: [
        Icon(icon, color: const Color(0xFF0066CC)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FluentTheme.of(context).typography.body,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: FluentTheme.of(context).typography.caption,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );

    // If onTap is provided, wrap with a button
    if (onTap != null) {
      return HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          return content;
        },
      );
    }

    return content;
  }
}
