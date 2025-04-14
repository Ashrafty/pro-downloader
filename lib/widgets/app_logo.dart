import 'package:fluent_ui/fluent_ui.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({
    super.key,
    this.size = 40,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF0066CC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              FluentIcons.download,
              color: Colors.white,
              size: size * 0.6,
            ),
          ),
        ),
        if (showText) 
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Text(
              'DownloadPro',
              style: FluentTheme.of(context).typography.title,
            ),
          ),
      ],
    );
  }
}
