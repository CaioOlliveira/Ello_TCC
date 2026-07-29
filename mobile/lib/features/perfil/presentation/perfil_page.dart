import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_mode_controller.dart';
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
      backgroundColor: adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
                StaggeredEntry(
                  index: 2,
                  child: _MenuCard(
                    usuario: usuario,
                    onEditPersonalInfo: () => context.go(editRoute),
                  ),
                ),
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
  final _picker = ImagePicker();

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
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 75,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.toLowerCase().endsWith('.png')
        ? 'png'
        : picked.name.toLowerCase().endsWith('.webp')
            ? 'webp'
            : 'jpeg';

    setState(() {
      _urlFoto = 'data:image/$extension;base64,${base64Encode(bytes)}';
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
      backgroundColor: adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
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
  });

  final UsuarioSessao? usuario;
  final VoidCallback onEditPersonalInfo;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.person_outline_rounded,
        'Informacoes pessoais',
        () => _showPersonalInfoSheet(
              context,
              usuario,
              onEditPersonalInfo,
            ),
      ),
      (Icons.shield_outlined, 'Segurança', null),
      (Icons.info_outline_rounded, 'Sobre o app', null),
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
                    color: adaptive(context, const Color(0xFFD9E2E5), AppDarkColors.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Informacoes pessoais',
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
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
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  label: const Text('Editar informacoes'),
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
                    color: adaptive(context, const Color(0xFF6B7F86), AppDarkColors.textSecondary),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF17324D), AppDarkColors.textPrimary),
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

class _PreferenciasCard extends ConsumerWidget {
  const _PreferenciasCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SwitchItem(
            icon: Icons.dark_mode_outlined,
            label: 'Modo escuro',
            value: isDark,
            onChanged: (value) =>
                ref.read(themeModeProvider.notifier).setDark(value),
          ),
          const _SwitchItem(
            icon: Icons.notifications_none_rounded,
            label: 'Receber lembretes',
            value: true,
          ),
          const _SwitchItem(
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
          color: adaptive(context, const Color(0xFFB8E6ED), AppDarkColors.border),
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
              color: adaptive(context, const Color(0xFF6B6B6B), AppDarkColors.textSecondary),
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
          color: adaptive(context, const Color(0xFFB8E6ED), AppDarkColors.border),
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
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final borderColor = adaptive(context, const Color(0xFFB8E6ED), AppDarkColors.border);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
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
      backgroundColor: adaptive(context, const Color(0xFFC8EAF0), AppDarkColors.tintedInfo),
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
