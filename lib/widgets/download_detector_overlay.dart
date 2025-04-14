import 'dart:async';
import 'package:flutter/material.dart';
import '../services/download_detector_service.dart';
import '../services/download_service.dart';
import 'download_prompt_widget.dart';

class DownloadDetectorOverlay extends StatefulWidget {
  final Widget child;

  const DownloadDetectorOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<DownloadDetectorOverlay> createState() => _DownloadDetectorOverlayState();
}

class _DownloadDetectorOverlayState extends State<DownloadDetectorOverlay> {
  final DownloadDetectorService _downloadDetectorService = DownloadDetectorService();
  final DownloadService _downloadService = DownloadService();
  
  StreamSubscription? _detectedLinksSubscription;
  String? _currentDetectedUrl;
  Map<String, dynamic>? _currentFileInfo;
  bool _isPromptVisible = false;
  
  @override
  void initState() {
    super.initState();
    
    // Listen for detected download links
    _detectedLinksSubscription = _downloadDetectorService.detectedLinks.listen((url) {
      _handleDetectedLink(url);
    });
  }
  
  @override
  void dispose() {
    _detectedLinksSubscription?.cancel();
    super.dispose();
  }
  
  // Handle a detected download link
  void _handleDetectedLink(String url) async {
    // Don't show multiple prompts for the same URL
    if (_isPromptVisible && _currentDetectedUrl == url) {
      return;
    }
    
    // Get file info
    final fileInfo = await _downloadService.getFileInfo(url);
    
    // Update state
    setState(() {
      _currentDetectedUrl = url;
      _currentFileInfo = fileInfo;
      _isPromptVisible = true;
    });
  }
  
  // Dismiss the prompt
  void _dismissPrompt() {
    setState(() {
      _isPromptVisible = false;
      _currentDetectedUrl = null;
      _currentFileInfo = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,
        
        // Download prompt overlay
        if (_isPromptVisible && _currentDetectedUrl != null && _currentFileInfo != null)
          Positioned(
            bottom: 20.0,
            right: 20.0,
            left: 20.0,
            child: DownloadPromptWidget(
              url: _currentDetectedUrl!,
              fileName: _currentFileInfo!['fileName'] as String? ?? 'Unknown file',
              fileType: _currentFileInfo!['contentType'] as String?,
              fileSize: _currentFileInfo!['contentLength'] != null 
                  ? double.tryParse(_currentFileInfo!['contentLength'] as String) 
                  : null,
              onDismiss: _dismissPrompt,
            ),
          ),
      ],
    );
  }
}
