import 'dart:io';

import 'package:flutter/material.dart';

/// Shows the custom logo if one was picked, otherwise a colored initial.
class PlatformAvatar extends StatelessWidget {
  const PlatformAvatar({
    super.key,
    required this.title,
    this.iconPath,
    this.size = 48,
  });

  final String title;
  final String? iconPath;
  final double size;

  static const _palette = [
    Color(0xFF00ADB5),
    Color(0xFF7C4DFF),
    Color(0xFFFF7043),
    Color(0xFF29B6F6),
    Color(0xFFEC407A),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);
    final path = iconPath;

    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Fall back to initials if the file is corrupt.
          errorBuilder: (_, _, _) => _initial(radius),
        ),
      );
    }
    return _initial(radius);
  }

  Widget _initial(BorderRadius radius) {
    final trimmed = title.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final color = _palette[trimmed.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
