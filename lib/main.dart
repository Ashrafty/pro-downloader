import 'package:fluent_ui/fluent_ui.dart' hide Colors;
import 'package:flutter/material.dart' hide Tooltip, IconButton;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'screens/home_screen.dart';
import 'models/download_model.dart';
import 'utils/app_theme.dart';
import 'services/download_service.dart';
import 'services/chunked_download_service.dart';
import 'services/simple_download_service.dart';
import 'services/download_detector_service.dart';
import 'services/update_service.dart';
import 'widgets/download_detector_overlay.dart';
import 'widgets/force_update_wrapper.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize download directory
  String downloadPath = '';
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      downloadPath = directory.path;
    } else {
      final directory = await getDownloadsDirectory();
      downloadPath = directory?.path ?? '';
    }
  } catch (e) {
    // Fallback to empty string if directory can't be determined
    // We can't use a logging framework here, so we'll just ignore the error
  }

  // Initialize the download detector service
  final downloadDetectorService = DownloadDetectorService();
  await downloadDetectorService.initialize();

  runApp(MyApp(initialDownloadPath: downloadPath));
}

class MyApp extends StatelessWidget {
  final String initialDownloadPath;

  const MyApp({super.key, this.initialDownloadPath = ''});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => DownloadManager()..setDownloadLocation(initialDownloadPath),
        ),
        Provider<DownloadService>(
          create: (context) => DownloadService(),
        ),
        Provider<ChunkedDownloadService>(
          create: (context) => ChunkedDownloadService(),
        ),
        Provider<SimpleDownloadService>(
          create: (context) => SimpleDownloadService(),
        ),
        Provider<DownloadDetectorService>(
          create: (context) => DownloadDetectorService(),
        ),
        Provider<UpdateService>(
          create: (context) => UpdateService(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final width = MediaQuery.of(context).size.width;
          final isMobile = width < 600;

          if (isMobile) {
            return MaterialApp(
              title: 'DownloadPro',
              themeMode: ThemeMode.light,
              theme: ThemeData(
                primaryColor: const Color(0xFF0066CC),
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFF0066CC),
                  secondary: const Color(0xFF0066CC),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                scaffoldBackgroundColor: const Color(0xFFF9F9F9),
              ),
              darkTheme: ThemeData.dark().copyWith(
                primaryColor: const Color(0xFF0066CC),
                colorScheme: ColorScheme.dark(
                  primary: const Color(0xFF0066CC),
                  secondary: const Color(0xFF0066CC),
                ),
              ),
              home: ForceUpdateWrapper(
                child: DownloadDetectorOverlay(
                  child: const HomeScreen(),
                ),
              ),
            );
          } else {
            return FluentApp(
              title: 'DownloadPro',
              themeMode: ThemeMode.light,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              home: ForceUpdateWrapper(
                child: DownloadDetectorOverlay(
                  child: const HomeScreen(),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
