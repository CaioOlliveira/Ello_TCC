import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/utils/avatar_image.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/staggered_entry.dart';

class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authSessionProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final backRoute = _routeFromOrigin(from);
    final editRoute =
        from == null ? '/perfil/editar' : '/perfil/editar?from=$from';

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context)
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StaggeredEntry(
                  index: 0,
                  child: _PerfilHeader(
                    title: 'Perfil e configurações',
                    onBack: () => context.go(backRoute),
                  ),
                ),
                const SizedBox(height: 10),
                StaggeredEntry(
                  index: 1,
                  child: _UsuarioCard(
                    usuario: usuario,
                    onEdit: () => context.go(editRoute),
                  ),
                ),
                const SizedBox(height: 16),
                StaggeredEntry(
                  index: 2,
                  child: _MenuCard(
                    usuario: usuario,
                    onEditPersonalInfo: () => context.go(editRoute),
                    from: from,
                    isDark: isDark,
                    onDarkModeChanged: (value) =>
                        ref.read(themeModeProvider.notifier).setDark(value),
                  ),
                ),
                const SizedBox(height: 28),
                if (from != 'idosos') ...[
                  StaggeredEntry(
                    index: 3,
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/idosos'),
                        icon: const Icon(
                          Icons.switch_account_rounded,
                          size: 21,
                        ),
                        label: const Text('Trocar de ficha'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF238FA1),
                          side: const BorderSide(color: Color(0xFF238FA1)),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                StaggeredEntry(
                  index: 4,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          await ref.read(sessaoUsuarioLocalProvider).limpar();
                          await ref
                              .read(appNavigationStateLocalProvider)
                              .limpar();
                        } catch (_) {}
                        if (!context.mounted) return;
                        ref.read(authSessionProvider.notifier).state = null;
                        ref.read(selectedIdosoProvider.notifier).state = null;
                        context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 21),
                      label: const Text('sair'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0B6985),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
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

class EditarPerfilPage extends ConsumerStatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  ConsumerState<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends ConsumerState<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  String? _urlFoto;
  String? _sexo;
  bool _loading = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final usuario = ref.read(authSessionProvider);
    _nomeController.text = usuario?.nome ?? '';
    _emailController.text = usuario?.email ?? '';
    _telefoneController.text = usuario?.telefone ?? '';
    _urlFoto = usuario?.urlFoto;
    _sexo = usuario?.sexo;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _selecionarFoto() async {
    final bytes = await pickAvatarImage(context);
    if (bytes == null) return;

    setState(() {
      _urlFoto = 'data:image/png;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final usuario = ref.read(authSessionProvider);
    if (usuario == null) return;
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final profileRoute = from == null ? '/perfil' : '/perfil?from=$from';

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final response = await ref.read(apiClientProvider).atualizarUsuario(
            id: usuario.id,
            nome: _nomeController.text.trim(),
            email: _emailController.text.trim(),
            telefone: _telefoneController.text.trim(),
            urlFoto: _urlFoto,
            sexo: _sexo,
          );
      final dados = response['dados'];
      if (dados is Map<String, dynamic>) {
        final sessaoAtualizada = UsuarioSessao.fromJson(dados)
            .copyWith(accessToken: usuario.accessToken);
        ref.read(authSessionProvider.notifier).state = sessaoAtualizada;
        try {
          await ref.read(sessaoUsuarioLocalProvider).salvar(sessaoAtualizada);
        } catch (_) {}
      }
      if (mounted) context.go(profileRoute);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _erro = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível atualizar o perfil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final profileRoute = from == null ? '/perfil' : '/perfil?from=$from';

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PerfilHeader(
                  title: 'Editar perfil',
                  onBack: () => context.go(profileRoute),
                ),
                const SizedBox(height: 18),
                Center(
                  child: InkWell(
                    onTap: _loading ? null : _selecionarFoto,
                    borderRadius: BorderRadius.circular(99),
                    child: _Avatar(
                      value: _urlFoto,
                      radius: 45,
                      placeholder: 'adicionar\nfoto',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _Input(
                  controller: _nomeController,
                  label: 'Nome',
                  validator: _obrigatorio,
                ),
                const SizedBox(height: 12),
                _Input(
                  controller: _emailController,
                  label: 'E-mail',
                  keyboardType: TextInputType.emailAddress,
                  validator: _obrigatorio,
                ),
                const SizedBox(height: 12),
                _Input(
                  controller: _telefoneController,
                  label: 'Telefone',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _SexoInput(
                  value: _sexo,
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _sexo = value);
                        },
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC0392B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _loading ? null : _salvar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B6985),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salvar alteracoes'),
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

class SegurancaPerfilPage extends StatelessWidget {
  const SegurancaPerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PerfilHeader(
                    title: 'Segurança',
                    onBack: () => context.go(_perfilRouteFromCurrent(context)),
                  ),
                  const SizedBox(height: 42),
                  Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: adaptive(context, const Color(0xFFE7F4F6),
                              AppDarkColors.tintedInfo),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF238FA1),
                          size: 42,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Segurança',
                              style: TextStyle(
                                color: adaptive(
                                    context,
                                    const Color(0xFF238FA1),
                                    AppDarkColors.textPrimary),
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gerencie a segurança da sua conta',
                              style: TextStyle(
                                color: adaptive(
                                    context,
                                    const Color(0xFF737D80),
                                    AppDarkColors.textSecondary),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 46),
                  _Panel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Alterar senha',
                          onTap: () => context.go('/perfil/seguranca/senha'),
                          showDivider: true,
                        ),
                        _MenuItem(
                          icon: Icons.group_outlined,
                          label: 'Acessos compartilhados',
                          onTap: () => context.go('/perfil/seguranca/acessos'),
                          showDivider: true,
                        ),
                        _MenuItem(
                          icon: Icons.history_rounded,
                          label: 'Histórico de acessos',
                          onTap: () =>
                              context.go('/perfil/seguranca/historico'),
                          showDivider: false,
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

class AlterarSenhaPage extends ConsumerStatefulWidget {
  const AlterarSenhaPage({super.key});

  @override
  ConsumerState<AlterarSenhaPage> createState() => _AlterarSenhaPageState();
}

class _AlterarSenhaPageState extends ConsumerState<AlterarSenhaPage> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();
  bool _loading = false;
  String? _erro;

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final usuario = ref.read(authSessionProvider);
    if (usuario == null) return;

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      await ref.read(apiClientProvider).alterarSenha(
            usuarioId: usuario.id,
            senhaAtual: _senhaAtualController.text,
            novaSenha: _novaSenhaController.text,
            confirmarNovaSenha: _confirmacaoController.text,
          );

      if (!mounted) return;
      _senhaAtualController.clear();
      _novaSenhaController.clear();
      _confirmacaoController.clear();
      _ignoreBottomMessage();
      context.go(_perfilRouteFromCurrent(context));
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível alterar a senha.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PerfilHeader(
                  title: 'Alterar senha',
                  onBack: () => context.go('/perfil/seguranca'),
                ),
                const SizedBox(height: 18),
                _Panel(
                  child: Column(
                    children: [
                      _Input(
                        controller: _senhaAtualController,
                        label: 'Senha atual',
                        obscureText: true,
                        validator: _obrigatorio,
                      ),
                      const SizedBox(height: 12),
                      _Input(
                        controller: _novaSenhaController,
                        label: 'Nova senha',
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Campo obrigatório.';
                          }
                          if (value.length < 6) {
                            return 'A senha deve ter pelo menos 6 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _Input(
                        controller: _confirmacaoController,
                        label: 'Confirmar nova senha',
                        obscureText: true,
                        validator: (value) {
                          if (value != _novaSenhaController.text) {
                            return 'As senhas precisam ser iguais.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC0392B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _loading ? null : _salvar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B6985),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Alterar senha'),
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

class SobreAppPage extends StatelessWidget {
  const SobreAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PerfilHeader(
                  title: 'Sobre nós',
                  onBack: () => context.go(_perfilRouteFromCurrent(context))),
              const SizedBox(height: 18),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'ello',
                        style: TextStyle(
                          color: Color(0xFF0E6F7E),
                          fontSize: 34,
                          fontWeight: FontWeight.w300,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Versão 0.1.0',
                      style: TextStyle(
                        color: Color(0xFF0B6985),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O ELLO organiza rotinas de cuidado, registros de saúde, compromissos, insumos e comunicação de apoio em uma única experiência.',
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF4F6268),
                            AppDarkColors.textSecondary),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SobreSection(
                      icon: Icons.favorite_border_rounded,
                      title: 'Para que serve',
                      body:
                          'O app ajuda familiares e cuidadores a acompanhar a rotina de uma pessoa idosa com mais clareza. Ele reúne monitoramentos de saúde, alimentação, remédios, agenda, gastos, insumos, equipamentos, contatos de emergência e conversas em família.',
                    ),
                    const SizedBox(height: 12),
                    const _SobreSection(
                      icon: Icons.fact_check_outlined,
                      title: 'Como usar',
                      body:
                          'Crie ou selecione uma ficha, marque quais módulos fazem parte do acompanhamento e registre as informações sempre que algo acontecer. Na tela inicial, use o resumo do dia e o menu de três pontos para escolher qual indicador acompanhar rapidamente.',
                    ),
                    const SizedBox(height: 12),
                    const _SobreSection(
                      icon: Icons.smart_toy_outlined,
                      title: 'IA e histórico',
                      body:
                          'A CoraIA usa as informações cadastradas no app para apoiar a interpretação da rotina: mensagens do chat com cuidadores, datas, registros de saúde, alimentação, gastos, agenda e demais módulos disponíveis para a ficha selecionada.',
                    ),
                    const SizedBox(height: 12),
                    const _SobreSection(
                      icon: Icons.support_agent_rounded,
                      title: 'Boas práticas',
                      body:
                          'Mantenha os registros atualizados, confira os dados antes de salvar e use os contatos de emergência quando precisar agir rapidamente. O app apoia o cuidado, mas não substitui orientação médica ou atendimento de urgência.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SobreSection extends StatelessWidget {
  const _SobreSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: adaptive(
              context,
              const Color(0xFFE3F7FA),
              AppDarkColors.surfaceAlt,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0B8DA0), size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: adaptive(
                    context,
                    const Color(0xFF073248),
                    AppDarkColors.textPrimary,
                  ),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  color: adaptive(
                    context,
                    const Color(0xFF4F6268),
                    AppDarkColors.textSecondary,
                  ),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerfilHeader extends StatelessWidget {
  const _PerfilHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(title: title, onBack: onBack);
  }
}

class _UsuarioCard extends StatelessWidget {
  const _UsuarioCard({
    required this.usuario,
    required this.onEdit,
  });

  final UsuarioSessao? usuario;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Row(
        children: [
          _Avatar(
            value: usuario?.urlFoto,
            radius: 48,
            placeholder: 'adicionar foto',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario?.nome ?? 'Usuário',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0B6985),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  icon: Icons.mail_outline_rounded,
                  text: usuario?.email ?? 'e-mail não informado',
                ),
                const SizedBox(height: 5),
                _InfoLine(
                  icon: Icons.phone_outlined,
                  text: usuario?.telefone?.isNotEmpty == true
                      ? usuario!.telefone!
                      : 'telefone não informado',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF238FA1),
              size: 25,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.usuario,
    required this.onEditPersonalInfo,
    required this.isDark,
    required this.onDarkModeChanged,
    this.from,
  });

  final UsuarioSessao? usuario;
  final VoidCallback onEditPersonalInfo;
  final bool isDark;
  final ValueChanged<bool> onDarkModeChanged;
  final String? from;

  @override
  Widget build(BuildContext context) {
    final suffix = from == null ? '' : '?from=$from';
    final items = [
      (
        Icons.person_outline_rounded,
        'Informações pessoais',
        () => _showPersonalInfoSheet(
              context,
              usuario,
              onEditPersonalInfo,
            ),
      ),
      (
        Icons.shield_outlined,
        'Segurança',
        () => context.go('/perfil/seguranca$suffix'),
      ),
      (
        Icons.info_outline_rounded,
        'Sobre nós',
        () => context.go('/perfil/sobre$suffix'),
      ),
    ];

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            _MenuItem(
              icon: items[index].$1,
              label: items[index].$2,
              onTap: items[index].$3,
              showDivider: true,
            ),
          _SwitchItem(
            icon: Icons.dark_mode_outlined,
            label: 'Modo escuro',
            value: isDark,
            onChanged: onDarkModeChanged,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

void _showPersonalInfoSheet(
  BuildContext context,
  UsuarioSessao? usuario,
  VoidCallback onEdit,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: adaptive(context, Colors.white, AppDarkColors.surface),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: adaptive(
                        context, const Color(0xFFD9E2E5), AppDarkColors.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Informações pessoais',
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248),
                      AppDarkColors.textPrimary),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _PersonalInfoLine(
                icon: Icons.person_outline_rounded,
                label: 'Nome',
                value: _valueOrNotInformed(usuario?.nome),
              ),
              _PersonalInfoLine(
                icon: Icons.mail_outline_rounded,
                label: 'E-mail',
                value: _valueOrNotInformed(usuario?.email),
              ),
              _PersonalInfoLine(
                icon: Icons.phone_outlined,
                label: 'Telefone',
                value: _valueOrNotInformed(usuario?.telefone),
              ),
              _PersonalInfoLine(
                icon: Icons.wc_rounded,
                label: 'Sexo',
                value: _valueOrNotInformed(usuario?.sexo),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  label: const Text('Editar informações'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E6F7E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PersonalInfoLine extends StatelessWidget {
  const _PersonalInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF238FA1), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF6B7F86),
                        AppDarkColors.textSecondary),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF17324D),
                        AppDarkColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 13),
                _SmallIcon(icon),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 15))),
                const Icon(Icons.chevron_right_rounded, size: 22),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 52),
      ],
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.icon,
    required this.label,
    this.value = false,
    this.showDivider = true,
    this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final bool showDivider;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 13),
              _SmallIcon(icon),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 15))),
              Switch(
                value: value,
                onChanged: onChanged ?? (_) {},
                activeThumbColor: const Color(0xFF2CA0B4),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 52),
      ],
    );
  }
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(
          color:
              adaptive(context, const Color(0xFFB8E6ED), AppDarkColors.border),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, color: const Color(0xFF238FA1), size: 20),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF238FA1), size: 17),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adaptive(context, const Color(0xFF6B6B6B),
                  AppDarkColors.textSecondary),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        border: Border.all(
          color:
              adaptive(context, const Color(0xFFB8E6ED), AppDarkColors.border),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        adaptive(context, const Color(0xFFB8E6ED), AppDarkColors.border);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: adaptive(context, Colors.white, AppDarkColors.surface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFF238FA1)),
        ),
      ),
    );
  }
}

class _SexoInput extends StatelessWidget {
  const _SexoInput({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        adaptive(context, const Color(0xFFB8E6ED), AppDarkColors.border);
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Sexo',
        filled: true,
        fillColor: adaptive(context, Colors.white, AppDarkColors.surface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFF238FA1)),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
        DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
        DropdownMenuItem(value: 'Outro', child: Text('Outro')),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.value,
    required this.radius,
    required this.placeholder,
  });

  final String? value;
  final double radius;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(value);

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          adaptive(context, const Color(0xFFC8EAF0), AppDarkColors.tintedInfo),
      backgroundImage: bytes != null
          ? MemoryImage(bytes)
          : value != null && value!.startsWith('http')
              ? NetworkImage(value!) as ImageProvider
              : null,
      child: bytes == null && (value == null || !value!.startsWith('http'))
          ? Text(
              placeholder,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6F9DA6),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

String? _obrigatorio(String? value) {
  if (value == null || value.trim().isEmpty) return 'Campo obrigatório.';
  return null;
}

String _valueOrNotInformed(String? value) {
  return value == null || value.trim().isEmpty ? 'não informado' : value.trim();
}

Uint8List? _dataImageBytes(String? value) {
  if (value == null || !value.startsWith('data:image')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

String _routeFromOrigin(String? from) {
  return switch (from) {
    'idosos' => '/idosos',
    'dashboard' => '/dashboard',
    'humor' => '/humor',
    'monitoramento' => '/monitoramento',
    'agenda' => '/agenda',
    'glicemia' => '/glicemia',
    'alimentacao' => '/alimentacao',
    'medicamentos' => '/medicamentos',
    'equipamentos' => '/equipamentos',
    'insumos' => '/insumos',
    'relatorios' => '/relatorios',
    'idoso-perfil' => '/idoso/perfil',
    _ => '/dashboard',
  };
}

String _perfilRouteFromCurrent(BuildContext context) {
  final from = GoRouterState.of(context).uri.queryParameters['from'];
  return from == null ? '/perfil' : '/perfil?from=$from';
}

void _ignoreBottomMessage() {}
