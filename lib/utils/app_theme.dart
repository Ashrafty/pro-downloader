import 'package:fluent_ui/fluent_ui.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0066CC);
  static const Color accentColor = Color(0xFF0066CC); // Blue accent color for all platforms
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color darkBackgroundColor = Color(0xFF1F1F1F);

  static FluentThemeData get lightTheme {
    return FluentThemeData(
      accentColor: AccentColor.swatch({
        'darkest': const Color.fromARGB(230, 0, 102, 204),
        'darker': const Color.fromARGB(204, 0, 102, 204),
        'dark': const Color.fromARGB(179, 0, 102, 204),
        'normal': accentColor,
        'light': const Color.fromARGB(128, 0, 102, 204),
        'lighter': const Color.fromARGB(77, 0, 102, 204),
        'lightest': const Color.fromARGB(26, 0, 102, 204),
      }),
      brightness: Brightness.light,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Segoe UI',
    );
  }

  static FluentThemeData get darkTheme {
    return FluentThemeData(
      accentColor: AccentColor.swatch({
        'darkest': const Color.fromARGB(230, 0, 102, 204),
        'darker': const Color.fromARGB(204, 0, 102, 204),
        'dark': const Color.fromARGB(179, 0, 102, 204),
        'normal': accentColor,
        'light': const Color.fromARGB(128, 0, 102, 204),
        'lighter': const Color.fromARGB(77, 0, 102, 204),
        'lightest': const Color.fromARGB(26, 0, 102, 204),
      }),
      brightness: Brightness.dark,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: darkBackgroundColor,
      fontFamily: 'Segoe UI',
    );
  }
}
