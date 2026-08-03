import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/staggered_entry.dart';

part 'cadastro_insumo_page.dart';
part 'detalhe_insumo_page.dart';
part 'atualizar_estoque_insumo_page.dart';

enum _InsumosView { lista, cadastro, detalhe, atualizar }

class InsumosPage extends ConsumerStatefulWidget {
  const InsumosPage({super.key});

  @override
  ConsumerState<InsumosPage> createState() => _InsumosPageState();
}

class _InsumosPageState extends ConsumerState<InsumosPage> {
  _InsumosView _view = _InsumosView.lista;
  List<InsumoResumo> _insumos = const [];
  InsumoResumo? _selected;
  String _selectedFilter = 'todos';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) {
      if (mounted) context.go('/idosos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ref.read(apiClientProvider).listarInsumos(
            idosoId: idoso.id,
            filtro: _selectedFilter,
          );
      if (!mounted) return;
      setState(() {
        _insumos = data;
        if (_selected != null) {
          _selected =
              data.where((item) => item.id == _selected!.id).firstOrNull;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar os insumos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showList() {
    setState(() {
      _view = _InsumosView.lista;
      _selected = null;
      _error = null;
    });
    _load();
  }

  void _showCadastro() {
    setState(() {
      _view = _InsumosView.cadastro;
      _selected = null;
      _error = null;
    });
  }

  void _selectFilter(String filter) {
    if (_selectedFilter == filter || _loading) return;
    setState(() => _selectedFilter = filter);
    _load();
  }

  void _showDetalhe(InsumoResumo insumo) {
    setState(() {
      _selected = insumo;
      _view = _InsumosView.detalhe;
      _error = null;
    });
  }

  void _showAtualizar() {
    if (_selected == null) return;
    setState(() {
      _view = _InsumosView.atualizar;
      _error = null;
    });
  }

  Future<void> _onCreated(InsumoResumo insumo) async {
    setState(() {
      _selected = null;
      _view = _InsumosView.lista;
    });
    await _load();
  }

  Future<void> _onUpdated(InsumoResumo insumo) async {
    setState(() {
      _selected = insumo;
      _view = _InsumosView.detalhe;
    });
    await _load();
  }

  Future<void> _deleteSelected() async {
    final insumo = _selected;
    if (insumo == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir insumo'),
        content: Text('Deseja excluir "${insumo.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).removerInsumo(id: insumo.id);
      if (!mounted) return;
      _showList();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir o insumo.')),
      );
    }
  }

  Future<void> _generateExpiredPdf() async {
    final idoso = ref.read(selectedIdosoProvider);
    if (idoso == null) {
      context.go('/idosos');
      return;
    }

    try {
      final vencidos = await ref.read(apiClientProvider).listarInsumos(
            idosoId: idoso.id,
            filtro: 'vencidos',
          );

      if (!mounted) return;
      if (vencidos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não há insumos vencidos para listar.')),
        );
        return;
      }

      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              'Insumos vencidos',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Idoso monitorado: ${idoso.nome}'),
            pw.Text('Gerado em: ${_formatBrazilianDate(DateTime.now())}'),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Insumo',
                'Estoque',
                'Unidade',
                'Validade',
                'Observações',
              ],
              data: [
                for (final insumo in vencidos)
                  [
                    insumo.nome,
                    _stockLabel(insumo.quantidadeUnidades),
                    _contentPerUnitLabel(insumo),
                    insumo.dataValidade == null
                        ? 'Não informada'
                        : _formatBrazilianDate(insumo.dataValidade!),
                    insumo.observacoes ?? '',
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'insumos-vencidos-${_formatIsoDate(DateTime.now())}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_view),
                  child: switch (_view) {
                    _InsumosView.lista => _InsumosListView(
                        insumos: _insumos,
                        loading: _loading,
                        error: _error,
                        onRetry: _load,
                        onBack: () => context.go('/monitoramento'),
                        onAdd: _showCadastro,
                        onHistory: () => context.push('/historico/insumos'),
                        onGeneratePdf: _generateExpiredPdf,
                        onOpen: _showDetalhe,
                        selectedFilter: _selectedFilter,
                        onFilterChanged: _selectFilter,
                      ),
                    _InsumosView.cadastro => _InsumoFormView(
                        idosoId: idoso?.id ?? '',
                        onCancel: _showList,
                        onSaved: _onCreated,
                      ),
                    _InsumosView.detalhe => _InsumoDetailView(
                        insumo: _selected,
                        onBack: _showList,
                        onAtualizar: _showAtualizar,
                        onDelete: _deleteSelected,
                      ),
                    _InsumosView.atualizar => _InsumoStockView(
                        insumo: _selected,
                        usuarioId: ref.watch(authSessionProvider)?.id,
                        onCancel: () =>
                            setState(() => _view = _InsumosView.detalhe),
                        onSaved: _onUpdated,
                      ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsumosListView extends StatelessWidget {
  const _InsumosListView({
    required this.insumos,
    required this.loading,
    required this.onRetry,
    required this.onBack,
    required this.onAdd,
    required this.onHistory,
    required this.onGeneratePdf,
    required this.onOpen,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.error,
  });

  final List<InsumoResumo> insumos;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback onHistory;
  final VoidCallback onGeneratePdf;
  final ValueChanged<InsumoResumo> onOpen;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                tooltip: 'Voltar',
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF2CA0B4),
                  size: 32,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  'Insumos',
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Text(
              'Controle de estoque dos produtos usados no cuidado',
              style: TextStyle(
                color: adaptive(context, const Color(0xFF8A8A8A),
                    AppDarkColors.textSecondary),
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(height: 7),
          _StatusFilters(
            selected: selectedFilter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3396A8)),
                  )
                : error != null
                    ? _ErrorState(message: error!, onRetry: onRetry)
                    : insumos.isEmpty
                        ? _EmptyState(filter: selectedFilter)
                        : GridView.builder(
                            padding: const EdgeInsets.only(bottom: 10),
                            itemCount: insumos.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 13,
                              mainAxisExtent: 154,
                            ),
                            itemBuilder: (context, index) {
                              final insumo = insumos[index];
                              return StaggeredEntry(
                                index: index,
                                child: _InsumoCard(
                                  insumo: insumo,
                                  onTap: () => onOpen(insumo),
                                ),
                              );
                            },
                          ),
          ),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_rounded, size: 20),
              label: const Text('Adicionar Insumo'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3BA7B8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: onHistory,
              style: OutlinedButton.styleFrom(
                foregroundColor: adaptive(context, const Color(0xFF073248),
                    AppDarkColors.textPrimary),
                side: const BorderSide(color: Color(0xFF2CA0B4), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Ver histórico'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onGeneratePdf,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: const Text('PDF dos vencidos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A7D8D),
                side: const BorderSide(color: Color(0xFF2CA0B4), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('todos', 'Todos', Color(0xFF3396A8), Icons.circle_outlined),
      ('acabando', 'Acabando', Color(0xFFFFC84D), Icons.warning_rounded),
      ('vencendo', 'Vencendo', Color(0xFFFF8A3D), Icons.circle_rounded),
      ('vencidos', 'Vencidos', Color(0xFFE95B5B), Icons.error_rounded),
    ];

    return Row(
      children: [
        for (final filter in filters) ...[
          Expanded(
            child: Material(
              color: selected == filter.$1
                  ? adaptive(context, const Color(0xFFDDF2F5),
                      AppDarkColors.tintedInfo)
                  : adaptive(context, Colors.white, AppDarkColors.surface),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => onChanged(filter.$1),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected == filter.$1
                          ? const Color(0xFF23899B)
                          : const Color(0xFF55B5C4),
                      width: selected == filter.$1 ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(filter.$4, color: filter.$3, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          filter.$2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected == filter.$1
                                ? const Color(0xFF006B7E)
                                : adaptive(context, const Color(0xFF6A6A6A),
                                    AppDarkColors.textSecondary),
                            fontSize: 11.2,
                            fontWeight: selected == filter.$1
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (filter != filters.last) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _InsumoCard extends StatelessWidget {
  const _InsumoCard({required this.insumo, required this.onTap});

  final InsumoResumo insumo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(insumo);

    return Material(
      color: adaptive(context, Colors.white, AppDarkColors.surface),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 8),
          child: Column(
            children: [
              Expanded(
                child: _ProductImage(value: insumo.fotoUrl, size: 70),
              ),
              Text(
                insumo.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(
                      context, Colors.black, AppDarkColors.textPrimary),
                  fontSize: 12.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _stockLabel(insumo.quantidadeUnidades),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adaptive(
                      context, Colors.black, AppDarkColors.textPrimary),
                  fontSize: 10.4,
                ),
              ),
              const SizedBox(height: 5),
              _StatusBadge(status: status, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.suffixText,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;
  final String? suffixText;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          minLines: minLines,
          maxLines: maxLines,
          style: TextStyle(
            color: adaptive(
                context, const Color(0xFF17324D), AppDarkColors.textPrimary),
            fontSize: 14,
          ),
          decoration: _inputDecoration(
            context,
            '',
            suffixIcon: suffixIcon,
            suffixText: suffixText,
          ),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 1, bottom: 3),
      child: Text(
        label,
        style: TextStyle(
          color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:
                    adaptive(context, Colors.black, AppDarkColors.textPrimary),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: adaptive(
                  context, const Color(0xFF003B4F), AppDarkColors.textPrimary),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.compact = false});

  final _InsumoStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 18,
        vertical: compact ? 2 : 6,
      ),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: compact ? 9 : 11),
          SizedBox(width: compact ? 3 : 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: compact ? 7.8 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.value, required this.size});

  final String? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider(value);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: adaptive(
            context, const Color(0xFFE9F5F7), AppDarkColors.tintedInfo),
        borderRadius: BorderRadius.circular(6),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? Icon(
              Icons.inventory_2_rounded,
              color: const Color(0xFF2CA0B4),
              size: size * 0.48,
            )
          : null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFF2CA0B4),
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: adaptive(context, const Color(0xFF555555),
                      AppDarkColors.textSecondary)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Voltar')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final message = filter == 'todos'
        ? 'Nenhum insumo cadastrado.'
        : 'Nenhum insumo encontrado neste filtro.';

    return Center(
      child: Text(
        message,
        style: TextStyle(
            color: adaptive(
                context, const Color(0xFF777777), AppDarkColors.textSecondary),
            fontSize: 13),
      ),
    );
  }
}

class _InsumoStatus {
  const _InsumoStatus({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

InputDecoration _inputDecoration(
  BuildContext context,
  String hint, {
  IconData? suffixIcon,
  String? suffixText,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color:
          adaptive(context, const Color(0xFF9A9A9A), AppDarkColors.textMuted),
      fontSize: 11,
    ),
    filled: true,
    fillColor: adaptive(context, Colors.white, AppDarkColors.surface),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
    suffixText: suffixText,
    suffixStyle: TextStyle(
        color: adaptive(
            context, const Color(0xFF8A8A8A), AppDarkColors.textSecondary),
        fontSize: 12),
    suffixIcon: suffixIcon == null
        ? null
        : Icon(suffixIcon, color: const Color(0xFF2CA0B4), size: 17),
    suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF3BA7B8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF3BA7B8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2FAD9F), width: 1.4),
    ),
  );
}

ButtonStyle _primaryButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF3BA7B8),
    foregroundColor: Colors.white,
    disabledBackgroundColor:
        adaptive(context, const Color(0xFF8ABEC7), AppDarkColors.borderStrong),
    disabledForegroundColor:
        adaptive(context, Colors.white, AppDarkColors.textMuted),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    minimumSize: const Size.fromHeight(52),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  );
}

_InsumoStatus _statusFor(InsumoResumo insumo) {
  final now = DateTime.now();
  final validade = insumo.dataValidade;
  if (validade != null) {
    final today = DateTime(now.year, now.month, now.day);
    final validDate = DateTime(validade.year, validade.month, validade.day);
    final days = validDate.difference(today).inDays;
    if (days < 0) {
      return const _InsumoStatus(
        label: 'Vencido',
        color: Color(0xFFE95B5B),
        background: Color(0xFFFFE4E4),
        icon: Icons.error_rounded,
      );
    }
    if (days <= insumo.diasAlertaValidade) {
      return const _InsumoStatus(
        label: 'Vencendo',
        color: Color(0xFFFF8A3D),
        background: Color(0xFFFFEAD8),
        icon: Icons.warning_rounded,
      );
    }
  }

  final minimo = insumo.alertaMinimoUnidades;
  if (minimo != null && insumo.quantidadeUnidades <= minimo) {
    return const _InsumoStatus(
      label: 'Comprar urgente',
      color: Color(0xFFFF5B5B),
      background: Color(0xFFFFDADA),
      icon: Icons.priority_high_rounded,
    );
  }

  final consumo = insumo.consumoMedioDiario;
  if (consumo != null && consumo > 0) {
    final dias = (insumo.quantidadeUnidades / consumo) *
        _frequencyDays(insumo.frequenciaUso);
    if (dias <= 3) {
      return const _InsumoStatus(
        label: 'Acabando',
        color: Color(0xFFE2A600),
        background: Color(0xFFFFF2BE),
        icon: Icons.warning_rounded,
      );
    }
  }

  return const _InsumoStatus(
    label: 'Cheio',
    color: Color(0xFF2FAD6B),
    background: Color(0xFFE1F6E8),
    icon: Icons.check_circle_rounded,
  );
}

String _quantityLabel(double value, String unit) {
  return '${_formatNumber(value)} $unit';
}

String _stockLabel(double value) {
  final suffix = value == 1 ? 'unidade' : 'unidades';
  return '${_formatNumber(value)} $suffix';
}

String _contentPerUnitLabel(InsumoResumo insumo) {
  final quantity = insumo.quantidadePorUnidade;
  if (quantity == null) return 'Não informado';
  return _quantityLabel(quantity, insumo.tipoUnidade);
}

String _forecastLabel(InsumoResumo insumo) {
  final consumo = insumo.consumoMedioDiario;
  if (consumo == null || consumo <= 0) return 'Sem previsão';
  final periods = insumo.quantidadeUnidades / consumo;
  final days = (periods * _frequencyDays(insumo.frequenciaUso)).floor();
  if (days <= 0) return 'Hoje';
  if (days == 1) return '1 dia';
  return '$days dias';
}

int _frequencyDays(String? frequency) {
  return switch (frequency) {
    'Semanal' => 7,
    'Mensal' => 30,
    _ => 1,
  };
}

String _frequencySuffix(String? frequency) {
  return switch (frequency) {
    'Semanal' => 'por semana',
    'Mensal' => 'por mês',
    _ => 'por dia',
  };
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

double? _toDouble(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String _formatBrazilianDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

String _formatIsoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime? _parseBrazilianDate(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

bool _isBeforeToday(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.isBefore(today);
}

String? _toIsoDate(String value) {
  final date = _parseBrazilianDate(value);
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

ImageProvider? _imageProvider(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('data:image')) {
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    try {
      return MemoryImage(base64Decode(value.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return NetworkImage(value);
  }
  return null;
}

String _imageExtension(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'png';
  if (lower.endsWith('.webp')) return 'webp';
  return 'jpeg';
}
