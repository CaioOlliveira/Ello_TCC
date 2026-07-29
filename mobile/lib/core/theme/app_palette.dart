import 'package:flutter/material.dart';

/// Fixed set of dark-mode tones used across the whole app so every screen's
/// dark theme feels like one cohesive palette instead of many one-offs.
///
/// Brand/accent teal colors, alert colors (green/orange/red) and gradients
/// are intentionally NOT part of this set — they stay identical in both
/// themes, since they carry the app's identity and semantic meaning.
class AppDarkColors {
  const AppDarkColors._();

  /// Scaffold background.
  static const bg = Color(0xFF0D1A1D);

  /// Default card / container surface.
  static const surface = Color(0xFF152427);

  /// Slightly lighter surface, for nested or secondary containers.
  static const surfaceAlt = Color(0xFF1C2E32);

  /// Elevated surface (e.g. bottom sheets, dialogs).
  static const surfaceElevated = Color(0xFF1A2B2F);

  /// Standard hairline border/divider color.
  static const border = Color(0xFF283B40);

  /// Stronger border, for inputs/focus outlines that need more contrast.
  static const borderStrong = Color(0xFF35494E);

  /// Primary heading/body text.
  static const textPrimary = Color(0xFFEAF3F4);

  /// Secondary text (subtitles, labels).
  static const textSecondary = Color(0xFF9FB3B7);

  /// Muted text (hints, placeholders, timestamps).
  static const textMuted = Color(0xFF75898D);

  /// Divider lines.
  static const divider = Color(0xFF223338);

  /// Dark counterpart for pale warm (pink/orange) alert/tip card backgrounds
  /// like `0xFFFFF1F1`.
  static const tintedWarn = Color(0xFF2E211D);

  /// Dark counterpart for pale teal info/tip/analysis card backgrounds like
  /// `0xFFCBEFF3`, `0xFFE7F4F6`, `0xFFC9E7ED`, `0xFFD8F1F4`.
  static const tintedInfo = Color(0xFF12262A);
}

/// Returns [dark] when the current theme is dark, [light] otherwise.
///
/// Use this to adapt existing hardcoded colors without touching their
/// light-mode value: `adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg)`.
Color adaptive(BuildContext context, Color light, Color dark) {
  return Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// True when the app is currently rendering in dark mode.
bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}
