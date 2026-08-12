import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Cabeçalho visual único das telas do aplicativo.
///
/// O [Stack] mantém o título no centro real da tela, independentemente da
/// largura dos controles laterais. O retorno é sempre apresentado apenas
/// pela seta, com uma área de toque acessível de 48 px.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.onBack,
    this.leading,
    this.trailing,
    this.backTooltip = 'Voltar',
    super.key,
  });

  static const double height = 52;
  static const double titleFontSize = 20;

  final String title;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? trailing;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          if (onBack != null || leading != null)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: leading ??
                      IconButton(
                        onPressed: onBack,
                        tooltip: backTooltip,
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                ),
              ),
            ),
          if (trailing != null)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(child: trailing),
              ),
            ),
        ],
      ),
    );
  }
}
