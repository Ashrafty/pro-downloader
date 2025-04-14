import 'package:fluent_ui/fluent_ui.dart';
import '../models/download_model.dart';

class DownloadSettingsWidget extends StatelessWidget {
  final DownloadManager downloadManager;

  const DownloadSettingsWidget({
    super.key,
    required this.downloadManager,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Download Settings',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              context,
              icon: FluentIcons.processing,
              title: 'Multi-thread Download',
              trailing: ToggleSwitch(
                checked: downloadManager.isMultiThreadEnabled,
                onChanged: (_) => downloadManager.toggleMultiThread(),
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              context,
              icon: FluentIcons.flow,
              title: 'Bandwidth Limit',
              trailing: Text(
                downloadManager.bandwidthLimit,
                style: FluentTheme.of(context).typography.body,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              context,
              icon: FluentIcons.folder,
              title: 'Download Location',
              trailing: Text(
                downloadManager.downloadLocation,
                style: FluentTheme.of(context).typography.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0066CC)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: FluentTheme.of(context).typography.body,
          ),
        ),
        trailing,
      ],
    );
  }
}
