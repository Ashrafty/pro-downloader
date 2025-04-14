import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class VideoInfo {
  final String title;
  final String url;
  final String thumbnailUrl;
  final String platform;
  final List<VideoQuality> qualities;
  final Map<String, dynamic> metadata;

  VideoInfo({
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.platform,
    required this.qualities,
    this.metadata = const {},
  });
}

class VideoQuality {
  final String label;
  final String url;
  final int? height;
  final int? width;
  final int? bitrate;
  final String format;

  VideoQuality({
    required this.label,
    required this.url,
    this.height,
    this.width,
    this.bitrate,
    required this.format,
  });
}

enum SocialPlatform {
  youtube,
  facebook,
  twitter,
  tiktok,
  unknown,
}

class VideoExtractionService {
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  
  // Identify the platform from the URL
  SocialPlatform identifyPlatform(String url) {
    final Uri uri = Uri.parse(url);
    final String host = uri.host.toLowerCase();
    
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return SocialPlatform.youtube;
    } else if (host.contains('facebook.com') || host.contains('fb.watch')) {
      return SocialPlatform.facebook;
    } else if (host.contains('twitter.com') || host.contains('x.com')) {
      return SocialPlatform.twitter;
    } else if (host.contains('tiktok.com')) {
      return SocialPlatform.tiktok;
    } else {
      return SocialPlatform.unknown;
    }
  }
  
  // Main extraction method
  Future<VideoInfo?> extractVideoInfo(String url) async {
    final platform = identifyPlatform(url);
    
    switch (platform) {
      case SocialPlatform.youtube:
        return await _extractYouTubeVideo(url);
      case SocialPlatform.facebook:
        return await _extractFacebookVideo(url);
      case SocialPlatform.twitter:
        return await _extractTwitterVideo(url);
      case SocialPlatform.tiktok:
        return await _extractTikTokVideo(url);
      case SocialPlatform.unknown:
        throw Exception('Unsupported platform or invalid URL');
    }
  }
  
  // YouTube extraction
  Future<VideoInfo?> _extractYouTubeVideo(String url) async {
    try {
      // For YouTube, we'll use a backend service since direct extraction is complex
      // In a real app, you would implement a proper YouTube extraction using youtube-dl or similar
      final apiUrl = 'https://api.downloadyoutubevideo.com/info?url=$url';
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'User-Agent': _userAgent},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          final videoData = data['video'];
          final List<VideoQuality> qualities = [];
          
          for (var format in videoData['formats']) {
            qualities.add(
              VideoQuality(
                label: '${format['height']}p',
                url: format['url'],
                height: format['height'],
                width: format['width'],
                bitrate: format['bitrate'],
                format: format['ext'],
              ),
            );
          }
          
          return VideoInfo(
            title: videoData['title'],
            url: url,
            thumbnailUrl: videoData['thumbnail'],
            platform: 'YouTube',
            qualities: qualities,
            metadata: {
              'duration': videoData['duration'],
              'author': videoData['uploader'],
            },
          );
        }
      }
      
      throw Exception('Failed to extract YouTube video info');
    } catch (e) {
      print('YouTube extraction error: $e');
      return null;
    }
  }
  
  // Facebook extraction
  Future<VideoInfo?> _extractFacebookVideo(String url) async {
    try {
      // For Facebook, we'll use a simplified approach
      // In a real app, you would need to handle authentication and use proper APIs
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // Extract video title
        final titleElement = document.querySelector('meta[property="og:title"]');
        final title = titleElement?.attributes['content'] ?? 'Facebook Video';
        
        // Extract thumbnail
        final thumbnailElement = document.querySelector('meta[property="og:image"]');
        final thumbnailUrl = thumbnailElement?.attributes['content'] ?? '';
        
        // Extract video URL (this is simplified and may not work for all videos)
        final videoElement = document.querySelector('meta[property="og:video:url"]');
        final videoUrl = videoElement?.attributes['content'] ?? '';
        
        if (videoUrl.isNotEmpty) {
          return VideoInfo(
            title: title,
            url: url,
            thumbnailUrl: thumbnailUrl,
            platform: 'Facebook',
            qualities: [
              VideoQuality(
                label: 'Standard',
                url: videoUrl,
                format: 'mp4',
              ),
            ],
          );
        }
      }
      
      throw Exception('Failed to extract Facebook video info');
    } catch (e) {
      print('Facebook extraction error: $e');
      return null;
    }
  }
  
  // Twitter extraction
  Future<VideoInfo?> _extractTwitterVideo(String url) async {
    try {
      // For Twitter, we'll use a simplified approach
      // In a real app, you would need to use Twitter's API or a specialized service
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // Extract video title
        final titleElement = document.querySelector('meta[property="og:title"]');
        final title = titleElement?.attributes['content'] ?? 'Twitter Video';
        
        // Extract thumbnail
        final thumbnailElement = document.querySelector('meta[property="og:image"]');
        final thumbnailUrl = thumbnailElement?.attributes['content'] ?? '';
        
        // Extract video URL
        final videoElement = document.querySelector('meta[property="og:video:url"]');
        final videoUrl = videoElement?.attributes['content'] ?? '';
        
        if (videoUrl.isNotEmpty) {
          return VideoInfo(
            title: title,
            url: url,
            thumbnailUrl: thumbnailUrl,
            platform: 'Twitter',
            qualities: [
              VideoQuality(
                label: 'Standard',
                url: videoUrl,
                format: 'mp4',
              ),
            ],
          );
        }
      }
      
      throw Exception('Failed to extract Twitter video info');
    } catch (e) {
      print('Twitter extraction error: $e');
      return null;
    }
  }
  
  // TikTok extraction
  Future<VideoInfo?> _extractTikTokVideo(String url) async {
    try {
      // For TikTok, we'll use a simplified approach
      // In a real app, you would need to use a specialized service or API
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // Extract video title
        final titleElement = document.querySelector('meta[property="og:title"]');
        final title = titleElement?.attributes['content'] ?? 'TikTok Video';
        
        // Extract thumbnail
        final thumbnailElement = document.querySelector('meta[property="og:image"]');
        final thumbnailUrl = thumbnailElement?.attributes['content'] ?? '';
        
        // Extract video URL
        final videoElement = document.querySelector('meta[property="og:video:url"]');
        final videoUrl = videoElement?.attributes['content'] ?? '';
        
        if (videoUrl.isNotEmpty) {
          return VideoInfo(
            title: title,
            url: url,
            thumbnailUrl: thumbnailUrl,
            platform: 'TikTok',
            qualities: [
              VideoQuality(
                label: 'Standard',
                url: videoUrl,
                format: 'mp4',
              ),
            ],
          );
        }
      }
      
      throw Exception('Failed to extract TikTok video info');
    } catch (e) {
      print('TikTok extraction error: $e');
      return null;
    }
  }
}
