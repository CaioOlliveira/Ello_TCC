import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/staggered_entry.dart';
import 'monitoramento_catalog.dart';

class MonitoramentoPage extends ConsumerStatefulWidget {
  const MonitoramentoPage({super.key});

  @override
  ConsumerState<MonitoramentoPage> createState() => _MonitoramentoPageState();
}

class _MonitoramentoPageState extends ConsumerState<MonitoramentoPage> {
  bool _saving = false;

  Future<void> _abrirSeletor() async {
    final idoso = ref.read(selectedIdosoProvider);

    if (idoso == null) {
      context.go('/idosos');
      return;
    }
    if (!idoso.podeEditarFicha) {
      _ignoreBottomMessage();
      return;
    }

    final selectedIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return _MonitoramentoPicker(initialIds: idoso.monitoramentos);
      },
    );

    if (selectedIds == null) return;
    await _salvarMonitoramentos(idoso, selectedIds);
  }

  Future<void> _salvarMonitoramentos(
    IdosoResumo idoso,
    List<String> selectedIds,
  ) async {
    setState(() => _saving = true);

    try {
      await ref.read(apiClientProvider).atualizarMonitoramentosIdoso(
            id: idoso.id,
            monitoramentos: selectedIds,
          );

      if (!mounted) return;
      ref.read(selectedIdosoProvider.notifier).state = idoso.copyWith(
        monitoramentos: selectedIds,
      );
      ref.invalidate(idososDoUsuarioProvider);
    } on ApiException {
      if (!mounted) return;
      _ignoreBottomMessage();
    } catch (_) {
      if (!mounted) return;
      _ignoreBottomMessage();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);
    final visibleModuleIds =
        idoso == null ? const <String>[] : idoso.monitoramentosVisiveis;
    final options = idoso == null
        ? const <MonitoramentoOption>[]
        : monitoramentoOptionsByIds(visibleModuleIds);
    final canManageMonitoramentos = idoso?.podeEditarFicha ?? false;
    final hasFullAccess = idoso?.temAcessoTotal ?? false;

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context)
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppPageHeader(title: 'Monitoramento'),
                    const SizedBox(height: 18),
                    Expanded(
                      child: idoso == null
                          ? const _MessageState(
                              icon: Icons.person_search_rounded,
                              title: 'Escolha uma ficha',
                              message:
                                  'Selecione uma ficha para ver os monitoramentos.',
                            )
                          : options.isEmpty
                              ? _MessageState(
                                  icon: Icons.dashboard_customize_outlined,
                                  title: hasFullAccess
                                      ? 'Nenhum monitoramento'
                                      : 'Sem acesso liberado',
                                  message: hasFullAccess
                                      ? 'Adicione ao menos um item para acompanhar.'
                                      : 'Peça para o responsável liberar algum monitoramento para você.',
                                )
                              : _MonitoramentoGrid(options: options),
                    ),
                    if (canManageMonitoramentos) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _abrirSeletor,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1696AA),
                                  ),
                                )
                              : const Icon(Icons.add_rounded, size: 27),
                          label: const Text('Adicionar registro'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: adaptive(
                                context,
                                const Color(0xFF073248),
                                AppDarkColors.textPrimary),
                            side: const BorderSide(
                              color: Color(0xFF1696AA),
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonitoramentoGrid extends StatelessWidget {
  const _MonitoramentoGrid({required this.options});

  final List<MonitoramentoOption> options;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 520 ? 3 : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(1, 0, 1, 4),
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            mainAxisExtent: 104,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            return StaggeredEntry(
              index: index,
              child: _MonitoramentoTile(
                option: option,
                onTap: () => context.go(option.route),
              ),
            );
          },
        );
      },
    );
  }
}

class _MonitoramentoTile extends StatefulWidget {
  const _MonitoramentoTile({
    required this.option,
    required this.onTap,
  });

  final MonitoramentoOption option;
  final VoidCallback onTap;

  @override
  State<_MonitoramentoTile> createState() => _MonitoramentoTileState();
}

class _MonitoramentoTileState extends State<_MonitoramentoTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _MonitoramentoTileContent(option: option, onTap: widget.onTap),
      ),
    );
  }
}

class _MonitoramentoTileContent extends StatelessWidget {
  const _MonitoramentoTileContent({
    required this.option,
    required this.onTap,
  });

  final MonitoramentoOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adaptive(context, Colors.white, AppDarkColors.surface),
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: adaptive(context, const Color(0xFFCFEFF4),
                      AppDarkColors.surfaceAlt),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  color: const Color(0xFF2BA8BA),
                  size: 30,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(
                            context, Colors.black, AppDarkColors.textPrimary),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF8C8C8C),
                            AppDarkColors.textSecondary),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: adaptive(context, const Color(0xFF8C8C8C),
                    AppDarkColors.textSecondary),
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF1696AA), size: 62),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adaptive(context, const Color(0xFF737373),
                  AppDarkColors.textSecondary),
              fontSize: 15,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoramentoPicker extends StatefulWidget {
  const _MonitoramentoPicker({required this.initialIds});

  final List<String> initialIds;

  @override
  State<_MonitoramentoPicker> createState() => _MonitoramentoPickerState();
}

class _MonitoramentoPickerState extends State<_MonitoramentoPicker> {
  late final Set<String> _selectedIds;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialIds.toSet();
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _errorMessage = null;
    });
  }

  void _salvar() {
    if (_selectedIds.isEmpty) {
      setState(() {
        _errorMessage = 'Selecione ao menos um monitoramento.';
      });
      return;
    }

    Navigator.of(context).pop(_selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'O que deseja monitorar',
                        style: TextStyle(
                          color: adaptive(context, const Color(0xFF073248),
                              AppDarkColors.textPrimary),
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    itemCount: monitoramentoOptions.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 13,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 88,
                    ),
                    itemBuilder: (context, index) {
                      final option = monitoramentoOptions[index];
                      return _PickerOptionTile(
                        option: option,
                        selected: _selectedIds.contains(option.id),
                        onTap: () => _toggle(option.id),
                      );
                    },
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC0392B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _salvar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3CB1C3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text('Salvar'),
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

class _PickerOptionTile extends StatelessWidget {
  const _PickerOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MonitoramentoOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? adaptive(context, const Color(0xFFE0F0F3), AppDarkColors.tintedInfo)
          : adaptive(context, Colors.white, AppDarkColors.surface),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(9, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF38AFC0)
                  : adaptive(
                      context, const Color(0xFFE3ECEE), AppDarkColors.border),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? adaptive(context, Colors.white, AppDarkColors.surface)
                      : adaptive(context, const Color(0xFFE9F5F7),
                          AppDarkColors.surfaceAlt),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  option.icon,
                  color: const Color(0xFF2BA8BA),
                  size: 25,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.selectionLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF394B52),
                        AppDarkColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                  ),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF38AFC0),
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _ignoreBottomMessage() {}
