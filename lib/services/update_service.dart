import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppVersion {
  final String version;
  final String buildNumber;
  final String releaseDate;
  final String downloadUrl;
  final List<String> releaseNotes;
  final bool forceUpdate;

  AppVersion({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      version: json['version'] as String,
      buildNumber: json['buildNumber'] as String,
      releaseDate: json['releaseDate'] as String,
      downloadUrl: json['downloadUrl'] as String,
      releaseNotes: List<String>.from(json['releaseNotes'] as List),
      forceUpdate: json['forceUpdate'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'releaseDate': releaseDate,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'forceUpdate': forceUpdate,
    };
  }

  bool isNewerThan(String currentVersion, String currentBuildNumber) {
    // First compare version numbers (e.g., 1.2.3)
    final List<int> currentParts = currentVersion.split('.').map(int.parse).toList();
    final List<int> newParts = version.split('.').map(int.parse).toList();

    // Ensure both lists have the same length
    while (currentParts.length < newParts.length) {
      currentParts.add(0);
    }
    while (newParts.length < currentParts.length) {
      newParts.add(0);
    }

    // Compare version parts
    for (int i = 0; i < currentParts.length; i++) {
      if (newParts[i] > currentParts[i]) {
        return true;
      } else if (newParts[i] < currentParts[i]) {
        return false;
      }
    }

    // If versions are equal, compare build numbers
    return int.parse(buildNumber) > int.parse(currentBuildNumber);
  }
}

class UpdateService {
  static const String _updateCheckUrl = 'https://example.com/api/app-updates/latest';
  static const String _lastCheckTimeKey = 'last_update_check_time';
  static const String _lastVersionKey = 'last_version_info';
  static const Duration _checkInterval = Duration(hours: 24);

  // Check for updates
  Future<AppVersion?> checkForUpdates({bool force = false}) async {
    try {
      // Get current app info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;

      // Check if we should check for updates
      if (!force) {
        final shouldCheck = await _shouldCheckForUpdates();
        if (!shouldCheck) {
          // Return cached version info if available
          final cachedVersion = await _getCachedVersionInfo();
          if (cachedVersion != null &&
              cachedVersion.isNewerThan(currentVersion, currentBuildNumber)) {
            return cachedVersion;
          }
          return null;
        }
      }

      // For testing purposes, return a mock update
      if (force) {
        // Create a mock update that is newer than the current version
        final mockUpdate = AppVersion(
          version: '2.0.0',  // Higher than current version
          buildNumber: '20',  // Higher than current build number
          releaseDate: '2025-04-15',
          downloadUrl: 'https://example.com/downloads/app-v2.0.0.zip',
          releaseNotes: [
            'Fixed pause/resume functionality for downloads',
            'Added force update mechanism',
            'Improved download speed and reliability',
            'Added support for more file types',
            'Fixed UI issues on desktop and mobile',
          ],
          forceUpdate: false,
        );

        // Cache the mock version info
        await _cacheVersionInfo(mockUpdate);

        return mockUpdate;
      }

      // In a real app, make the API call
      // final response = await http.get(Uri.parse(_updateCheckUrl));

      // Update last check time
      await _updateLastCheckTime();

      // In a real app, parse the response
      // if (response.statusCode == 200) {
      //   final Map<String, dynamic> data = json.decode(response.body);
      //   final AppVersion latestVersion = AppVersion.fromJson(data);
      //
      //   // Cache the version info
      //   await _cacheVersionInfo(latestVersion);
      //
      //   // Check if this is a newer version
      //   if (latestVersion.isNewerThan(currentVersion, currentBuildNumber)) {
      //     return latestVersion;
      //   }
      // }

      return null;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  // Check if we should check for updates based on the last check time
  Future<bool> _shouldCheckForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckTime = prefs.getInt(_lastCheckTimeKey);

      if (lastCheckTime == null) {
        return true;
      }

      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
      final now = DateTime.now();

      return now.difference(lastCheck) > _checkInterval;
    } catch (e) {
      return true;
    }
  }

  // Update the last check time
  Future<void> _updateLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error updating last check time: $e');
    }
  }

  // Cache the version info
  Future<void> _cacheVersionInfo(AppVersion version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastVersionKey, json.encode(version.toJson()));
    } catch (e) {
      debugPrint('Error caching version info: $e');
    }
  }

  // Get cached version info
  Future<AppVersion?> _getCachedVersionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final versionJson = prefs.getString(_lastVersionKey);

      if (versionJson != null) {
        final Map<String, dynamic> data = json.decode(versionJson);
        return AppVersion.fromJson(data);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting cached version info: $e');
      return null;
    }
  }

  // Get the current app version
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  // Get the current app build number
  Future<String> getCurrentBuildNumber() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.buildNumber;
  }
}
