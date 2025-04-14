import 'package:fluent_ui/fluent_ui.dart';

class MobileBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const MobileBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, FluentIcons.download, 'Downloads'),
          _buildNavItem(1, FluentIcons.history, 'History'),
          _buildNavItem(2, FluentIcons.calendar, 'Schedule'),
          _buildNavItem(3, FluentIcons.settings, 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: Button(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 10)),
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
        ),
        onPressed: () => onChanged(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0066CC) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF0066CC) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
