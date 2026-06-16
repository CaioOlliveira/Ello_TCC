import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

enum AuthMode { login, cadastro }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  AuthMode _mode = AuthMode.login;
  bool _loading = false;
  String? _errorMessage;

  bool get _isCadastro => _mode == AuthMode.cadastro;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);

      if (_isCadastro) {
        await apiClient.cadastrar(
          nome: _nomeController.text.trim(),
          email: _emailController.text.trim(),
          senha: _senhaController.text,
        );
      } else {
        await apiClient.login(
          email: _emailController.text.trim(),
          senha: _senhaController.text,
        );
      }

      if (mounted) context.go('/idosos');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Nao foi possivel conectar ao servidor. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMode(AuthMode mode) {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.lg + bottomInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHeader(theme: theme),
                      const SizedBox(height: AppSizes.xl),
                      _AuthCard(
                        mode: _mode,
                        formKey: _formKey,
                        nomeController: _nomeController,
                        emailController: _emailController,
                        senhaController: _senhaController,
                        loading: _loading,
                        errorMessage: _errorMessage,
                        onModeChanged: _changeMode,
                        onSubmit: _submit,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_outline,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          'Ello',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          'Cuidado conectado, simples e seguro.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.darkBlue.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.mode,
    required this.formKey,
    required this.nomeController,
    required this.emailController,
    required this.senhaController,
    required this.loading,
    required this.onModeChanged,
    required this.onSubmit,
    this.errorMessage,
  });

  final AuthMode mode;
  final GlobalKey<FormState> formKey;
  final TextEditingController nomeController;
  final TextEditingController emailController;
  final TextEditingController senhaController;
  final bool loading;
  final String? errorMessage;
  final ValueChanged<AuthMode> onModeChanged;
  final VoidCallback onSubmit;

  bool get isCadastro => mode == AuthMode.cadastro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModeSelector(mode: mode, onModeChanged: onModeChanged),
              const SizedBox(height: AppSizes.lg),
              Text(
                isCadastro ? 'Criar sua conta' : 'Entrar na conta',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                isCadastro
                    ? 'Preencha seus dados para comecar.'
                    : 'Use seu e-mail e senha cadastrados.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.darkBlue.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              if (isCadastro) ...[
                AppTextField(
                  label: 'Nome',
                  controller: nomeController,
                  validator: Validators.requiredText,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.person_outline,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: AppSizes.md),
              ],
              AppTextField(
                label: 'E-mail',
                controller: emailController,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.mail_outline,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: AppSizes.md),
              AppTextField(
                label: 'Senha',
                controller: senhaController,
                validator: Validators.password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline,
                autofillHints: [
                  isCadastro
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSizes.md),
                _ErrorBox(message: errorMessage!),
              ],
              const SizedBox(height: AppSizes.lg),
              AppButton(
                label: isCadastro ? 'Criar conta' : 'Entrar',
                icon: isCadastro ? Icons.person_add_alt_1 : Icons.login,
                onPressed: loading ? null : onSubmit,
              ),
              if (loading) ...[
                const SizedBox(height: AppSizes.md),
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.onModeChanged,
  });

  final AuthMode mode;
  final ValueChanged<AuthMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AuthMode>(
      segments: const [
        ButtonSegment(
          value: AuthMode.login,
          icon: Icon(Icons.login),
          label: Text('Entrar'),
        ),
        ButtonSegment(
          value: AuthMode.cadastro,
          icon: Icon(Icons.person_add_alt_1),
          label: Text('Criar conta'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selected) => onModeChanged(selected.first),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
