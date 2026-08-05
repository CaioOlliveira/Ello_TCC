import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

class ModuleHeader extends StatelessWidget {
  const ModuleHeader({
    required this.title,
    required this.onBack,
    this.trailing,
    this.showWordmark = false,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final bool showWordmark;

  static const titleColor = Color(0xFF238FA1);
  static const titleStyle = TextStyle(
    color: titleColor,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        ModuleBackButton(onPressed: onBack),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle.copyWith(
              color: adaptive(context, titleColor, AppDarkColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 78,
            child: Align(alignment: Alignment.centerRight, child: trailing)),
      ],
    );

    if (!showWordmark) return header;

    return Column(
      children: [
        const Text(
          'ello',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF0E6F7E),
            fontSize: 34,
            fontWeight: FontWeight.w300,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        header,
      ],
    );
  }
}

class ModuleBackButton extends StatelessWidget {
  const ModuleBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF238FA1),
        padding: const EdgeInsets.only(left: 0, right: 8),
        minimumSize: const Size(78, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      icon: const Icon(Icons.chevron_left_rounded, size: 30),
      label: const Text('Voltar'),
    );
  }
}
