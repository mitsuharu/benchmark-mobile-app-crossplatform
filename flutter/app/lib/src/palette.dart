import 'package:flutter/material.dart';

/// The colours every implementation draws the screens with.
class Palette {
  const Palette._();

  static const primary = Color(0xFF111827);
  static const secondary = Color(0xFFE5E7EB);
  static const subtitle = Color(0xFF6B7280);
  static const description = Color(0xFF4B5563);
  static const placeholder = Color(0xFF9CA3AF);
  static const error = Color(0xFFB91C1C);
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? Palette.secondary : Palette.primary,
        foregroundColor: secondary ? Palette.primary : Colors.white,
        disabledBackgroundColor: Palette.primary.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 51842 → "51,842", as the other implementations format star counts.
String groupThousands(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
