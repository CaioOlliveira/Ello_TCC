import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Entrar no Ello',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSizes.sm),
              const Text('Acesso provisório para testar o fluxo inicial.'),
              const SizedBox(height: AppSizes.lg),
              const AppTextField(label: 'E-mail'),
              const SizedBox(height: AppSizes.md),
              const AppTextField(label: 'Senha'),
              const SizedBox(height: AppSizes.lg),
              AppButton(
                label: 'Entrar',
                icon: Icons.login,
                onPressed: () => context.go('/idosos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
