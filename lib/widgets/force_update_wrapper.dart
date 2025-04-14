import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';
import '../screens/update_screen.dart';

class ForceUpdateWrapper extends StatefulWidget {
  final Widget child;

  const ForceUpdateWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ForceUpdateWrapper> createState() => _ForceUpdateWrapperState();
}

class _ForceUpdateWrapperState extends State<ForceUpdateWrapper> {
  bool _checking = true;
  bool _updateRequired = false;
  AppVersion? _updateInfo;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      if (!mounted) return;
      final updateService = Provider.of<UpdateService>(context, listen: false);
      final updateInfo = await updateService.checkForUpdates();

      if (!mounted) return;
      if (updateInfo != null && updateInfo.forceUpdate) {
        setState(() {
          _updateRequired = true;
          _updateInfo = updateInfo;
        });
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      // Show a loading indicator while checking for updates
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_updateRequired && _updateInfo != null) {
      // Show the update screen if a force update is required
      return UpdateScreen(
        updateInfo: _updateInfo!,
        forceUpdate: true,
      );
    }

    // Otherwise, show the normal app
    return widget.child;
  }
}
