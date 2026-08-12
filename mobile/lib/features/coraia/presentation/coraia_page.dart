import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';

class CoraIAPage extends StatelessWidget {
  const CoraIAPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppPageHeader(title: 'CoraIA'),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: adaptive(context, const Color(0xFFD1F2F6),
                                AppDarkColors.tintedInfo),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF0E6F7E),
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Essa funcionalidade vai chegar em breve.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: adaptive(context, const Color(0xFF5E6B73),
                                AppDarkColors.textSecondary),
                            fontSize: 16,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
