import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Colors;
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

class UpdateScreen extends StatelessWidget {
  final AppVersion updateInfo;
  final bool forceUpdate;

  const UpdateScreen({
    super.key,
    required this.updateInfo,
    this.forceUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return isMobile ? _buildMobileUI(context) : _buildDesktopUI(context);
  }

  Widget _buildDesktopUI(BuildContext context) {
    return FluentTheme(
      data: FluentThemeData.light(),
      child: NavigationView(
        content: ScaffoldPage(
          header: PageHeader(
            title: const Text('Update Available'),
            commandBar: CommandBar(
              mainAxisAlignment: MainAxisAlignment.end,
              primaryItems: [
                CommandBarButton(
                  icon: const Icon(FluentIcons.download),
                  label: const Text('Download Update'),
                  onPressed: () => _downloadUpdate(),
                ),
                if (!forceUpdate)
                  CommandBarButton(
                    icon: const Icon(FluentIcons.cancel),
                    label: const Text('Later'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          content: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'A new version of the app is available!',
                    style: FluentTheme.of(context).typography.title,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Version ${updateInfo.version} (Build ${updateInfo.buildNumber})',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Released on: ${updateInfo.releaseDate}',
                    style: FluentTheme.of(context).typography.body,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'What\'s New:',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 10),
                  ...updateInfo.releaseNotes.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(note)),
                      ],
                    ),
                  )),
                  const SizedBox(height: 20),
                  if (forceUpdate)
                    InfoBar(
                      title: const Text('This update is required to continue using the app.'),
                      severity: InfoBarSeverity.warning,
                      isLong: true,
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Button(
                        child: const Text('Download Update'),
                        onPressed: () => _downloadUpdate(),
                      ),
                      const SizedBox(width: 10),
                      if (!forceUpdate)
                        Button(
                          child: const Text('Later'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileUI(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: const Color(0xFF0066CC),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0066CC),
          secondary: const Color(0xFF0066CC),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Update Available'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'A new version of the app is available!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Version ${updateInfo.version} (Build ${updateInfo.buildNumber})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                'Released on: ${updateInfo.releaseDate}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'What\'s New:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ...updateInfo.releaseNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(note)),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              if (forceUpdate)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This update is required to continue using the app.',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _downloadUpdate(),
                    child: const Text('Download Update'),
                  ),
                  const SizedBox(width: 10),
                  if (!forceUpdate)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Later'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadUpdate() async {
    final url = Uri.parse(updateInfo.downloadUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
