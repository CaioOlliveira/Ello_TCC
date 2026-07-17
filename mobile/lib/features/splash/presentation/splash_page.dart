import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF3396A8),
                  size: 40,
                ),
                SizedBox(height: 10),
                Text(
                  'ello',
                  style: TextStyle(
                    color: Color(0xFF0E6F7E),
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
