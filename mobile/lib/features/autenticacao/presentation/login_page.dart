import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/google_auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_text_field.dart';

enum AuthView { landing, login, cadastro, cadastroGoogle }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _cadastroFormKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  AuthView _view = AuthView.landing;
  bool _loading = false;
  bool _aceitouTermos = false;
  String? _errorMessage;
  GoogleAuthResult? _googleCadastro;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    if (!(_loginFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.login(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
      );
      final dados = response['dados'];
      final usuario = dados is Map<String, dynamic> ? dados['usuario'] : null;

      if (usuario is Map<String, dynamic>) {
        ref.read(authSessionProvider.notifier).state =
            UsuarioSessao.fromJson(usuario);
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

  Future<void> _submitCadastro() async {
    FocusScope.of(context).unfocus();

    if (!(_cadastroFormKey.currentState?.validate() ?? false)) return;

    if (!_aceitouTermos) {
      setState(() {
        _errorMessage =
            'Aceite os termos de uso e a politica de privacidade para continuar.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.cadastrar(
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        telefone: _telefoneController.text.trim(),
        senha: _senhaController.text,
      );

      if (!mounted) return;
      setState(() {
        _view = AuthView.login;
        _errorMessage = null;
        _senhaController.clear();
        _confirmarSenhaController.clear();
      });
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

  Future<void> _submitGoogleLogin() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final googleAuth = await ref.read(googleAuthServiceProvider).signIn();
      if (googleAuth == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final response = await ref.read(apiClientProvider).loginGoogle(
            idToken: googleAuth.idToken,
          );
      final dados = response['dados'];
      final usuario = dados is Map<String, dynamic> ? dados['usuario'] : null;

      if (usuario is Map<String, dynamic>) {
        ref.read(authSessionProvider.notifier).state =
            UsuarioSessao.fromJson(usuario);
        if (mounted) context.go('/idosos');
        return;
      }

      final precisaCadastro =
          dados is Map<String, dynamic> && dados['precisaCadastro'] == true;

      if (precisaCadastro && mounted) {
        _googleCadastro = googleAuth;
        _nomeController.text = googleAuth.nome ?? '';
        _emailController.text = googleAuth.email;
        _telefoneController.clear();
        setState(() {
          _view = AuthView.cadastroGoogle;
          _aceitouTermos = false;
          _errorMessage =
              'Essa conta Google ainda nao esta cadastrada no Ello. Complete seu cadastro para continuar.';
        });
        return;
      }

      if (mounted) {
        setState(() {
          _errorMessage =
              'Nao foi possivel encontrar os dados da conta Google.';
        });
      }
    } on GoogleAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Nao foi possivel entrar com Google: $error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogleCadastro() async {
    FocusScope.of(context).unfocus();

    final google = _googleCadastro;
    if (google == null) {
      setState(() {
        _view = AuthView.landing;
        _errorMessage = 'Entre com Google novamente para continuar.';
      });
      return;
    }

    if (!(_cadastroFormKey.currentState?.validate() ?? false)) return;

    if (!_aceitouTermos) {
      setState(() {
        _errorMessage =
            'Aceite os termos de uso e a politica de privacidade para continuar.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(apiClientProvider).cadastrarGoogle(
            idToken: google.idToken,
            nome: _nomeController.text.trim(),
            telefone: _telefoneController.text.trim(),
          );
      final dados = response['dados'];
      final usuario = dados is Map<String, dynamic> ? dados['usuario'] : null;

      if (usuario is Map<String, dynamic>) {
        ref.read(authSessionProvider.notifier).state =
            UsuarioSessao.fromJson(usuario);
      }

      if (mounted) context.go('/idosos');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Nao foi possivel cadastrar com Google: $error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTo(AuthView view) {
    FocusScope.of(context).unfocus();
    setState(() {
      _view = view;
      _errorMessage = null;
    });
  }

  void _showPendingProviderMessage(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login com $provider sera liberado em breve.'),
      ),
    );
  }

  String? _confirmarSenhaValidator(String? value) {
    final passwordError = Validators.password(value);
    if (passwordError != null) return passwordError;

    if (value != _senhaController.text) {
      return 'As senhas precisam ser iguais.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // resizeToAvoidBottomInset (default true) already shrinks the body
        // for the keyboard; adding extra bottom padding on top of that
        // double-reserves space and pushes content off-screen.
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: switch (_view) {
                AuthView.landing => _LandingView(
                    key: const ValueKey('landing-view'),
                    onApplePressed: () => _showPendingProviderMessage('Apple'),
                    onGooglePressed: _loading ? null : _submitGoogleLogin,
                    onEmailPressed: () => _goTo(AuthView.login),
                    onCadastroPressed: () => _goTo(AuthView.cadastro),
                    errorMessage: _errorMessage,
                    loading: _loading,
                  ),
                AuthView.login => _LoginFormView(
                    key: const ValueKey('login-view'),
                    formKey: _loginFormKey,
                    emailController: _emailController,
                    senhaController: _senhaController,
                    loading: _loading,
                    errorMessage: _errorMessage,
                    onBack: () => _goTo(AuthView.landing),
                    onSubmit: _submitLogin,
                  ),
                AuthView.cadastro => _CadastroFormView(
                    key: const ValueKey('cadastro-view'),
                    formKey: _cadastroFormKey,
                    nomeController: _nomeController,
                    emailController: _emailController,
                    telefoneController: _telefoneController,
                    senhaController: _senhaController,
                    confirmarSenhaController: _confirmarSenhaController,
                    loading: _loading,
                    errorMessage: _errorMessage,
                    aceitouTermos: _aceitouTermos,
                    onBack: () => _goTo(AuthView.landing),
                    onSubmit: _submitCadastro,
                    onAceitouTermosChanged: (value) {
                      setState(() {
                        _aceitouTermos = value ?? false;
                        _errorMessage = null;
                      });
                    },
                    confirmarSenhaValidator: _confirmarSenhaValidator,
                  ),
                AuthView.cadastroGoogle => _GoogleCadastroView(
                    key: const ValueKey('google-cadastro-view'),
                    formKey: _cadastroFormKey,
                    nomeController: _nomeController,
                    emailController: _emailController,
                    telefoneController: _telefoneController,
                    loading: _loading,
                    errorMessage: _errorMessage,
                    aceitouTermos: _aceitouTermos,
                    fotoUrl: _googleCadastro?.fotoUrl,
                    onBack: () => _goTo(AuthView.landing),
                    onSubmit: _submitGoogleCadastro,
                    onAceitouTermosChanged: (value) {
                      setState(() {
                        _aceitouTermos = value ?? false;
                        _errorMessage = null;
                      });
                    },
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingView extends StatelessWidget {
  const _LandingView({
    required this.onApplePressed,
    required this.onGooglePressed,
    required this.onEmailPressed,
    required this.onCadastroPressed,
    this.errorMessage,
    this.loading = false,
    super.key,
  });

  final VoidCallback onApplePressed;
  final VoidCallback? onGooglePressed;
  final VoidCallback onEmailPressed;
  final VoidCallback onCadastroPressed;
  final String? errorMessage;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ello',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: const Color(0xFF0E6F7E),
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    'Transforme o cuidado em uma jornada mais leve!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF177385),
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSizes.lg),
                    _ErrorBox(message: errorMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
        _BottomChoicesPanel(
          onApplePressed: onApplePressed,
          onGooglePressed: onGooglePressed,
          onEmailPressed: onEmailPressed,
          onCadastroPressed: onCadastroPressed,
          loadingGoogle: loading,
        ),
      ],
    );
  }
}

class _LoginFormView extends StatelessWidget {
  const _LoginFormView({
    required this.formKey,
    required this.emailController,
    required this.senhaController,
    required this.loading,
    required this.onBack,
    required this.onSubmit,
    this.errorMessage,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController senhaController;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.md,
            AppSizes.md,
            AppSizes.md,
            0,
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: loading ? null : onBack,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF177385),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Voltar'),
              ),
              const Spacer(),
              Text(
                'ello',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0E6F7E),
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 72),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.xl,
                  AppSizes.lg,
                  AppSizes.lg + MediaQuery.viewInsetsOf(context).bottom,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - AppSizes.xl - AppSizes.lg)
                            .clamp(0, double.infinity),
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Entre com e-mail',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF177385),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Text(
                            'Use seu e-mail e senha cadastrados.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF6F8288),
                            ),
                          ),
                          const SizedBox(height: AppSizes.xl),
                          _InputWrapper(
                            child: AppTextField(
                              label: 'E-mail',
                              controller: emailController,
                              validator: Validators.email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.mail_outline,
                              autofillHints: const [AutofillHints.email],
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          _InputWrapper(
                            child: AppTextField(
                              label: 'Senha',
                              controller: senhaController,
                              validator: Validators.password,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.lock_outline,
                              autofillHints: const [AutofillHints.password],
                            ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: AppSizes.md),
                            _ErrorBox(message: errorMessage!),
                          ],
                          const Spacer(),
                          const SizedBox(height: AppSizes.lg),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: loading ? null : onSubmit,
                              style: _primaryButtonStyle(),
                              child: loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CadastroFormView extends StatelessWidget {
  const _CadastroFormView({
    required this.formKey,
    required this.nomeController,
    required this.emailController,
    required this.telefoneController,
    required this.senhaController,
    required this.confirmarSenhaController,
    required this.loading,
    required this.aceitouTermos,
    required this.onBack,
    required this.onSubmit,
    required this.onAceitouTermosChanged,
    required this.confirmarSenhaValidator,
    this.errorMessage,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nomeController;
  final TextEditingController emailController;
  final TextEditingController telefoneController;
  final TextEditingController senhaController;
  final TextEditingController confirmarSenhaController;
  final bool loading;
  final bool aceitouTermos;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final ValueChanged<bool?> onAceitouTermosChanged;
  final FormFieldValidator<String> confirmarSenhaValidator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.md,
            AppSizes.md,
            AppSizes.md,
            0,
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: loading ? null : onBack,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF177385),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Voltar'),
              ),
              const Spacer(),
              Text(
                'ello',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0E6F7E),
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 72),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.xl + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crie sua conta',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF177385),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Text(
                              'Cadastre-se para comecar a organizar seus cuidados',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF6F8288),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      const _SignupIllustration(),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xl),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'Nome completo',
                      controller: nomeController,
                      validator: Validators.requiredText,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline,
                      autofillHints: const [AutofillHints.name],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'E-mail',
                      controller: emailController,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline,
                      autofillHints: const [AutofillHints.email],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'Telefone',
                      controller: telefoneController,
                      validator: Validators.requiredText,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.phone_outlined,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _PhoneInputFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'Senha',
                      controller: senhaController,
                      validator: Validators.password,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.lock_outline,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'Confirmar senha',
                      controller: confirmarSenhaController,
                      validator: confirmarSenhaValidator,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline,
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  CheckboxListTile(
                    value: aceitouTermos,
                    onChanged: loading ? null : onAceitouTermosChanged,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    title: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: Color(0xFF6F8288),
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(text: 'aceito os '),
                          TextSpan(
                            text: 'termos de uso',
                            style: TextStyle(color: Color(0xFF177385)),
                          ),
                          TextSpan(text: ' e a '),
                          TextSpan(
                            text: 'politica de privacidade',
                            style: TextStyle(color: Color(0xFF177385)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSizes.md),
                    _ErrorBox(message: errorMessage!),
                  ],
                  const SizedBox(height: AppSizes.xl),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: loading ? null : onSubmit,
                      style: _primaryButtonStyle(),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Criar Conta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleCadastroView extends StatelessWidget {
  const _GoogleCadastroView({
    required this.formKey,
    required this.nomeController,
    required this.emailController,
    required this.telefoneController,
    required this.loading,
    required this.aceitouTermos,
    required this.onBack,
    required this.onSubmit,
    required this.onAceitouTermosChanged,
    this.errorMessage,
    this.fotoUrl,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nomeController;
  final TextEditingController emailController;
  final TextEditingController telefoneController;
  final bool loading;
  final bool aceitouTermos;
  final String? errorMessage;
  final String? fotoUrl;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final ValueChanged<bool?> onAceitouTermosChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.md,
            AppSizes.md,
            AppSizes.md,
            0,
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: loading ? null : onBack,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF177385),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Voltar'),
              ),
              const Spacer(),
              Text(
                'Google',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF3C4043),
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 72),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.xl + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFFE8F0FE),
                      backgroundImage: fotoUrl == null || fotoUrl!.isEmpty
                          ? null
                          : NetworkImage(fotoUrl!),
                      child: fotoUrl == null || fotoUrl!.isEmpty
                          ? const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFF1A73E8),
                              size: 42,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Text(
                    'Complete seu cadastro',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF202124),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'Essa conta Google ainda nao esta cadastrada no Ello. Confirme seus dados para continuar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F6368),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'Nome completo',
                      controller: nomeController,
                      validator: Validators.requiredText,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline,
                      autofillHints: const [AutofillHints.name],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'E-mail Google',
                      controller: emailController,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline,
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InputWrapper(
                    child: AppTextField(
                      label: 'Telefone',
                      controller: telefoneController,
                      validator: Validators.requiredText,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.phone_outlined,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _PhoneInputFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  CheckboxListTile(
                    value: aceitouTermos,
                    onChanged: loading ? null : onAceitouTermosChanged,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    title: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: Color(0xFF5F6368),
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(text: 'aceito os '),
                          TextSpan(
                            text: 'termos de uso',
                            style: TextStyle(color: Color(0xFF1A73E8)),
                          ),
                          TextSpan(text: ' e a '),
                          TextSpan(
                            text: 'politica de privacidade',
                            style: TextStyle(color: Color(0xFF1A73E8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSizes.md),
                    _ErrorBox(message: errorMessage!),
                  ],
                  const SizedBox(height: AppSizes.xl),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: loading ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Cadastrar com Google'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buffer = StringBuffer();
    var selectionIndex = truncated.length;

    for (var i = 0; i < truncated.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(truncated[i]);
    }

    final text = buffer.toString();

    if (selectionIndex >= 1) selectionIndex += 1;
    if (selectionIndex >= 3) selectionIndex += 2;
    if (selectionIndex >= 8) selectionIndex += 1;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selectionIndex.clamp(0, text.length),
      ),
    );
  }
}

class _BottomChoicesPanel extends StatelessWidget {
  const _BottomChoicesPanel({
    required this.onApplePressed,
    required this.onGooglePressed,
    required this.onEmailPressed,
    required this.onCadastroPressed,
    this.loadingGoogle = false,
  });

  final VoidCallback onApplePressed;
  final VoidCallback? onGooglePressed;
  final VoidCallback onEmailPressed;
  final VoidCallback onCadastroPressed;
  final bool loadingGoogle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xl,
        AppSizes.lg,
        AppSizes.xl,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0E6F7E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          _ProviderButton(
            label: 'Entre com Apple',
            icon: const _AppleBadge(),
            onPressed: onApplePressed,
          ),
          const SizedBox(height: AppSizes.md),
          _ProviderButton(
            label: loadingGoogle ? 'Entrando...' : 'Fazer login com google',
            icon: const _GoogleBadge(),
            onPressed: onGooglePressed,
          ),
          const SizedBox(height: AppSizes.md),
          _ProviderButton(
            label: 'E-mail',
            onPressed: onEmailPressed,
          ),
          const SizedBox(height: AppSizes.xl),
          TextButton(
            onPressed: onCadastroPressed,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  TextSpan(text: 'Nao tem uma conta? '),
                  TextSpan(
                    text: 'Cadastre-se',
                    style: TextStyle(
                      color: Color(0xFF89E7EF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0E6F7E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (icon != null)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 34, child: Center(child: icon)),
              ),
            Center(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _InputWrapper extends StatelessWidget {
  const _InputWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF8A9AA0)),
          prefixIconColor: const Color(0xFF5F7A82),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.md,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7E0E3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF89E7EF),
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFC1C1)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFC1C1)),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _SignupIllustration extends StatelessWidget {
  const _SignupIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFD6EEF2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 18,
            child: Container(
              width: 46,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2E6FA4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 4,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD0B5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 26,
            child: Container(
              width: 44,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF9FC0F1),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 12,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF4DFC8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned(
            right: 8,
            top: 6,
            child: Icon(
              Icons.favorite,
              color: Color(0xFF3396A8),
              size: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4A80F0),
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}

class _AppleBadge extends StatelessWidget {
  const _AppleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD9D4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB73A2A)),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB73A2A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );
}
