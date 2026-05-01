import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static Color primary = const Color(0xFF5B5EF7);
  static Color primaryPurple = const Color(0xFF7C4DFF);
  static Color primaryDark = const Color(0xFF3F35B5);
  static Color primaryLight = const Color(0xFF2C2554);
  static Color secondary = const Color(0xFF24242C);
  static Color accent = const Color(0xFF7C4DFF);

  static Color background = const Color(0xFF0F1015);
  static Color surface = const Color(0xFF171821);
  static Color surfaceSoft = const Color(0xFF20222D);
  static Color border = const Color(0xFF303341);
  static Color shellDark = const Color(0xFF16171D);
  static Color shellDarkSoft = const Color(0xFF20212A);
  static Color shellBorder = const Color(0xFF30313B);
  static Color shellText = const Color(0xFFF8FAFC);
  static Color shellTextMuted = const Color(0xFFA3A3B2);

  static Color onAccent = const Color(0xFFFFFFFF);
  static Color shadow = const Color(0x3D000000);
  static Color textPrimary = const Color(0xFFF8FAFC);
  static Color textSecondary = const Color(0xFFB8BECC);
  static Color textMuted = const Color(0xFF7F8796);

  static Color success = const Color(0xFF16A34A);
  static Color warning = const Color(0xFFD97706);
  static Color error = const Color(0xFFDC2626);
  static Color info = const Color(0xFF0284C7);

  static void apply({required bool dark, required Color primaryColor}) {
    primary = primaryColor;
    primaryPurple = primaryColor;
    primaryDark = _darken(primaryColor);
    primaryLight = dark
        ? Color.alphaBlend(
            primaryColor.withValues(alpha: 0.22),
            const Color(0xFF20222D),
          )
        : Color.alphaBlend(primaryColor.withValues(alpha: 0.14), Colors.white);
    accent = primaryColor;
    secondary = dark ? const Color(0xFF24242C) : const Color(0xFFEEF1F6);

    background = dark ? const Color(0xFF0F1015) : const Color(0xFFF5F6FA);
    surface = dark ? const Color(0xFF171821) : Colors.white;
    surfaceSoft = dark ? const Color(0xFF20222D) : const Color(0xFFF0F2F7);
    border = dark ? const Color(0xFF303341) : const Color(0xFFDDE2EA);
    shellDark = dark ? const Color(0xFF16171D) : const Color(0xFFFFFFFF);
    shellDarkSoft = dark ? const Color(0xFF20212A) : const Color(0xFFF0F2F7);
    shellBorder = dark ? const Color(0xFF30313B) : const Color(0xFFDDE2EA);
    shellText = dark ? const Color(0xFFF8FAFC) : const Color(0xFF101218);
    shellTextMuted = dark ? const Color(0xFFA3A3B2) : const Color(0xFF6B7280);

    onAccent = Colors.white;
    shadow = dark ? const Color(0x52000000) : const Color(0x24000000);
    textPrimary = dark ? const Color(0xFFF8FAFC) : const Color(0xFF101218);
    textSecondary = dark ? const Color(0xFFB8BECC) : const Color(0xFF475569);
    textMuted = dark ? const Color(0xFF7F8796) : const Color(0xFF94A3B8);
  }

  static Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor();
  }
}
