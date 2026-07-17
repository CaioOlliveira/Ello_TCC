import 'package:flutter/material.dart';

class CoraIAPage extends StatelessWidget {
  const CoraIAPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1F2F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF0E6F7E),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'CoraIA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF073248),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Essa funcionalidade vai chegar em breve.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF5E6B73),
                      fontSize: 16,
                      height: 1.35,
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
