import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Floating circular icon button (white background, soft shadow) used for
/// header actions such as accessing the caregiver's account settings.
class ActionIconButton extends StatelessWidget {
  const ActionIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: const Color(0xFF0E6F7E), size: 21),
          ),
        ),
      ),
    );
  }
}
