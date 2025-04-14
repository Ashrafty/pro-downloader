# Downloader

A powerful, cross-platform download manager built with Flutter that works on both desktop and mobile platforms. This application allows you to download files from various sources, manage your downloads, and keep the application up to date.

## Features

### Download Management
- Download files from any URL
- Support for downloading videos from Facebook, YouTube, TikTok, and Twitter
- Support for downloading large zip files (over 100MB) from file hosting services
- Pause and resume downloads at any time
- Cancel ongoing downloads
- Retry failed downloads
- Track download progress with detailed information (speed, remaining time)
- Automatically detect when download links are tapped and handle them within the application

### User Interface
- Modern, clean interface using Fluent UI for desktop and Material Design for mobile
- Consistent blue accent color across platforms
- Longer, more visible progress bars on desktop
- Double-tap completed files to open them on desktop
- Responsive design that adapts to different screen sizes

### Application Updates
- Built-in update checker
- Force update mechanism for critical updates
- Detailed release notes for each update
- Easy update process

## Platforms

The application is designed to work on multiple platforms:
- Windows
- macOS
- Linux
- Android
- iOS

## Installation

### Desktop
1. Download the latest release for your platform from the project's releases page
2. Extract the downloaded archive
3. Run the executable file

### Mobile
1. Download the APK file for Android or IPA file for iOS from the project's releases page
2. Install the app on your device (you may need to enable installation from unknown sources on Android)
3. Open the app

## Usage

### Adding a Download
1. Click or tap the "Add Download" button
2. Enter the URL of the file you want to download
3. Click or tap "Download"

### Managing Downloads
- **Pause**: Click or tap the pause button on an active download
- **Resume**: Click or tap the resume button on a paused download
- **Cancel**: Click or tap the cancel button on an active or paused download
- **Retry**: Click or tap the retry button on a failed download
- **Open**: Double-tap a completed download to open the file (desktop only)

### Settings
- **Download Location**: Change where downloaded files are saved
- **Auto-Open Completed**: Toggle whether to automatically open files when downloads complete
- **Check for Updates**: Manually check if a new version of the app is available

## Development

### Prerequisites
- Flutter SDK (version 3.0.0 or higher)
- Dart SDK (version 2.17.0 or higher)
- Android Studio / VS Code with Flutter extensions

### Setup
1. Clone the repository
   ```
   git clone https://github.com/Ashrafty/pro-downloader.git
   ```
2. Navigate to the project directory
   ```
   cd downloader
   ```
3. Get dependencies
   ```
   flutter pub get
   ```
4. Run the app
   ```
   flutter run -d <device>
   ```

### Project Structure
- `lib/main.dart`: Application entry point
- `lib/screens/`: UI screens
- `lib/widgets/`: Reusable UI components
- `lib/services/`: Business logic and services
- `lib/models/`: Data models
- `lib/utils/`: Utility functions

## Technologies Used

- **Flutter**: Cross-platform UI framework
- **Fluent UI**: Windows-style UI components for desktop
- **Material Design**: Google's design system for mobile
- **Dio**: HTTP client for file downloads
- **Provider**: State management
- **SQLite**: Local database for download history
- **Package Info Plus**: For app version information

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [Fluent UI for Flutter](https://pub.dev/packages/fluent_ui)
- [Material Design](https://material.io/design)
- [Dio](https://pub.dev/packages/dio)
- [Provider](https://pub.dev/packages/provider)

---

Built with ❤️ using Flutter
