import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/avatar_image.dart';
import '../../../shared/widgets/staggered_entry.dart';

class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authSessionProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final backRoute = _routeFromOrigin(from);
    final editRoute =
        from == null ? '/perfil/editar' : '/perfil/editar?from=$from';

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StaggeredEntry(
                  index: 0,
                  child: _PerfilHeader(onBack: () => context.go(backRoute)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Perfil e configurações',
                  style: TextStyle(
                    color: Color(0xFF238FA1),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
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
                StaggeredEntry(index: 2, child: _MenuCard(from: from)),
                const SizedBox(height: 16),
                const Text(
                  'Preferências',
                  style: TextStyle(
                    color: Color(0xFF238FA1),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const StaggeredEntry(index: 3, child: _PreferenciasCard()),
                const SizedBox(height: 28),
                if (from != 'idosos') ...[
                  StaggeredEntry(
                    index: 4,
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
                  index: 5,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
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
          );
      final dados = response['dados'];
      if (dados is Map<String, dynamic>) {
        ref.read(authSessionProvider.notifier).state =
            UsuarioSessao.fromJson(dados);
      }
      if (mounted) context.go(profileRoute);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _erro = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erro = 'Nao foi possivel atualizar o perfil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final profileRoute = from == null ? '/perfil' : '/perfil?from=$from';

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PerfilHeader(onBack: () => context.go(profileRoute)),
                const SizedBox(height: 16),
                const Text(
                  'Editar perfil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF238FA1),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
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
                        : const Text('Salvar alterações'),
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

class SegurancaPerfilPage extends ConsumerStatefulWidget {
  const SegurancaPerfilPage({super.key});

  @override
  ConsumerState<SegurancaPerfilPage> createState() =>
      _SegurancaPerfilPageState();
}

class _SegurancaPerfilPageState extends ConsumerState<SegurancaPerfilPage> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso.')),
      );
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
      backgroundColor: const Color(0xFFFCFCFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PerfilHeader(
                    onBack: () => context.go(_perfilRouteFromCurrent(context))),
                const SizedBox(height: 16),
                const Text(
                  'Segurança',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF238FA1),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
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
      backgroundColor: const Color(0xFFFCFCFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PerfilHeader(
                  onBack: () => context.go(_perfilRouteFromCurrent(context))),
              const SizedBox(height: 16),
              const Text(
                'Sobre o App',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF238FA1),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              const _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
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
                    SizedBox(height: 16),
                    Text(
                      'Versão 0.1.0',
                      style: TextStyle(
                        color: Color(0xFF0B6985),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'O ELLO organiza rotinas de cuidado, registros de saúde, compromissos, insumos e comunicação de apoio em uma única experiência.',
                      style: TextStyle(
                        color: Color(0xFF4F6268),
                        fontSize: 14,
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
    );
  }
}

class _PerfilHeader extends StatelessWidget {
  const _PerfilHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF238FA1),
              size: 32,
            ),
          ),
        ),
        const Text(
          'ello',
          style: TextStyle(
            color: Color(0xFF0E6F7E),
            fontSize: 34,
            fontWeight: FontWeight.w300,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ],
    );
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
                  usuario?.nome ?? 'Usuario',
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
                  text: usuario?.email ?? 'email nao informado',
                ),
                const SizedBox(height: 5),
                _InfoLine(
                  icon: Icons.phone_outlined,
                  text: usuario?.telefone?.isNotEmpty == true
                      ? usuario!.telefone!
                      : 'telefone nao informado',
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
  const _MenuCard({this.from});

  final String? from;

  @override
  Widget build(BuildContext context) {
    final suffix = from == null ? '' : '?from=$from';
    final items = [
      (Icons.person_outline_rounded, 'Informações pessoais', null),
      (
        Icons.shield_outlined,
        'Segurança',
        () => context.go('/perfil/seguranca$suffix'),
      ),
      (
        Icons.info_outline_rounded,
        'Sobre o App',
        () => context.go('/perfil/sobre$suffix'),
      ),
      (
        Icons.tune_rounded,
        'Permissões',
        () => context.go('/permissoes'),
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
              showDivider: index < items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _PreferenciasCard extends StatelessWidget {
  const _PreferenciasCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SwitchItem(icon: Icons.dark_mode_outlined, label: 'Modo escuro'),
          _SwitchItem(
            icon: Icons.notifications_none_rounded,
            label: 'Receber lembretes',
            value: true,
          ),
          _SwitchItem(
            icon: Icons.lock_outline_rounded,
            label: 'Senha',
            value: true,
            showDivider: false,
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
  });

  final IconData icon;
  final String label;
  final bool value;
  final bool showDivider;

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
                onChanged: (_) {},
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
        border: Border.all(color: const Color(0xFFB8E6ED)),
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
            style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 13),
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB8E6ED)),
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFB8E6ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFB8E6ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFF238FA1)),
        ),
      ),
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
      backgroundColor: const Color(0xFFC8EAF0),
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
  if (value == null || value.trim().isEmpty) return 'Campo obrigatorio.';
  return null;
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
