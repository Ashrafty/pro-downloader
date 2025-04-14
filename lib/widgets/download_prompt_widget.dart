import 'package:flutter/material.dart' hide FilledButton, IconButton, showDialog;
import 'package:fluent_ui/fluent_ui.dart' hide Colors;
import 'dart:io';
import '../services/download_detector_service.dart';
import '../utils/file_utils.dart';

class DownloadPromptWidget extends StatefulWidget {
  final String url;
  final String fileName;
  final String? fileType;
  final double? fileSize;
  final VoidCallback onDismiss;

  const DownloadPromptWidget({
    super.key,
    required this.url,
    required this.fileName,
    this.fileType,
    this.fileSize,
    required this.onDismiss,
  });

  @override
  State<DownloadPromptWidget> createState() => _DownloadPromptWidgetState();
}

class _DownloadPromptWidgetState extends State<DownloadPromptWidget> {
  final DownloadDetectorService _downloadDetectorService = DownloadDetectorService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Use different UI for mobile and desktop
    if (Platform.isAndroid || Platform.isIOS) {
      return _buildMobilePrompt();
    } else {
      return _buildDesktopPrompt();
    }
  }

  // Build the mobile prompt
  Widget _buildMobilePrompt() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 10.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.file_download,
                color: Colors.blue[700],
                size: 24.0,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'Download Detected',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(
                  Icons.close,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Text(
            'File: ${widget.fileName}',
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.fileType != null && widget.fileType!.isNotEmpty)
            Text(
              'Type: ${widget.fileType}',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.grey[700],
              ),
            ),
          if (widget.fileSize != null && widget.fileSize! > 0)
            Text(
              'Size: ${FileUtils.formatFileSize(widget.fileSize! * 1024 * 1024)}',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.grey[700],
              ),
            ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onDismiss,
                child: const Text('Ignore'),
              ),
              const SizedBox(width: 8.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Download'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build the desktop prompt
  Widget _buildDesktopPrompt() {
    return ContentDialog(
      title: const Text('Download Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File: ${widget.fileName}'),
          if (widget.fileType != null && widget.fileType!.isNotEmpty)
            Text('Type: ${widget.fileType}'),
          if (widget.fileSize != null && widget.fileSize! > 0)
            Text('Size: ${FileUtils.formatFileSize(widget.fileSize! * 1024 * 1024)}'),
          const SizedBox(height: 8.0),
          Text('URL: ${widget.url}'),
        ],
      ),
      actions: [
        Button(
          onPressed: widget.onDismiss,
          child: const Text('Ignore'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _startDownload,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: ProgressRing(
                    strokeWidth: 2.0,
                  ),
                )
              : const Text('Download'),
        ),
      ],
    );
  }

  // Start the download
  void _startDownload() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _downloadDetectorService.startDetectedDownload(widget.url);
      if (mounted) {
        widget.onDismiss();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        if (Platform.isAndroid || Platform.isIOS) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting download: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: const Text('Error'),
              content: Text('Error starting download: $e'),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }
}
