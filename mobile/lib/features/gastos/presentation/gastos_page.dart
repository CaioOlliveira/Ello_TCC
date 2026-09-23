import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/app_page_header.dart';

enum _GastosPeriodoFiltro { dia, semana, mes, ano, personalizado }

class GastosPage extends ConsumerStatefulWidget {
  const GastosPage({super.key});

  @override
  ConsumerState<GastosPage> createState() => _GastosPageState();
}

class _GastosPageState extends ConsumerState<GastosPage> {
  _GastosPeriodoFiltro _filtro = _GastosPeriodoFiltro.mes;
  DateTime _referencia = DateTime.now();
  DateTimeRange? _periodoPersonalizado;
  GastosPeriodo? _dados;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);

    if (idoso == null) {
      if (mounted) context.go('/idosos');
      return;
    }

    if (idoso.ehDono != true || usuario?.accessToken?.isEmpty != false) {
      setState(() {
        _loading = false;
        _error = 'Apenas o responsavel pela ficha pode acessar os gastos.';
      });
      return;
    }

    final loadToken = ++_loadToken;
    final range = _rangeAtual();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dados = await ref.read(apiClientProvider).listarGastos(
            idosoId: idoso.id,
            inicio: _isoDate(range.start),
            fim: _isoDate(range.end),
            accessToken: usuario!.accessToken!,
          );
      if (!mounted || loadToken != _loadToken) return;
      setState(() => _dados = dados);
    } on ApiException catch (error) {
      if (!mounted || loadToken != _loadToken) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || loadToken != _loadToken) return;
      setState(() => _error = 'Nao foi possivel carregar os gastos.');
    } finally {
      if (mounted && loadToken == _loadToken) setState(() => _loading = false);
    }
  }

  DateTimeRange _rangeAtual() {
    final now = DateTime.now();
    final refDate = _referencia.isAfter(now) ? now : _referencia;

    switch (_filtro) {
      case _GastosPeriodoFiltro.dia:
        return DateTimeRange(
            start: _startOfDay(refDate), end: _endOfDay(refDate));
      case _GastosPeriodoFiltro.semana:
        final start =
            _startOfDay(refDate).subtract(Duration(days: refDate.weekday - 1));
        return DateTimeRange(
          start: start,
          end: _endOfDay(start.add(const Duration(days: 6)).isAfter(now)
              ? now
              : start.add(const Duration(days: 6))),
        );
      case _GastosPeriodoFiltro.mes:
        final start = DateTime(refDate.year, refDate.month);
        final end = DateTime(refDate.year, refDate.month + 1, 0);
        return DateTimeRange(
          start: start,
          end: _endOfDay(end.isAfter(now) ? now : end),
        );
      case _GastosPeriodoFiltro.ano:
        final start = DateTime(refDate.year);
        final end = DateTime(refDate.year, 12, 31);
        return DateTimeRange(
          start: start,
          end: _endOfDay(end.isAfter(now) ? now : end),
        );
      case _GastosPeriodoFiltro.personalizado:
        final custom = _periodoPersonalizado;
        if (custom != null) {
          return DateTimeRange(
            start: _startOfDay(custom.start),
            end: _endOfDay(custom.end.isAfter(now) ? now : custom.end),
          );
        }
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: _endOfDay(now),
        );
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    if (_filtro == _GastosPeriodoFiltro.personalizado) {
      final current = _rangeAtual();
      final picked = await showDateRangePicker(
        context: context,
        locale: const Locale('pt', 'BR'),
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: DateTimeRange(
          start: current.start,
          end: current.end.isAfter(now) ? now : current.end,
        ),
      );
      if (picked == null) return;
      setState(() {
        _periodoPersonalizado = picked;
        _referencia = picked.end;
      });
      await _load();
      return;
    }

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDate: _referencia.isAfter(now) ? now : _referencia,
    );
    if (picked == null) return;
    setState(() => _referencia = picked);
    await _load();
  }

  void _changeFilter(_GastosPeriodoFiltro filtro) {
    if (_filtro == filtro) return;
    setState(() {
      _filtro = filtro;
      if (filtro == _GastosPeriodoFiltro.personalizado) {
        _periodoPersonalizado ??= _rangeAtual();
      }
    });
    _load();
  }

  void _movePeriod(int direction) {
    final now = DateTime.now();
    final next = switch (_filtro) {
      _GastosPeriodoFiltro.dia => _referencia.add(Duration(days: direction)),
      _GastosPeriodoFiltro.semana =>
        _referencia.add(Duration(days: 7 * direction)),
      _GastosPeriodoFiltro.mes =>
        DateTime(_referencia.year, _referencia.month + direction, 1),
      _GastosPeriodoFiltro.ano => DateTime(_referencia.year + direction),
      _GastosPeriodoFiltro.personalizado => _referencia,
    };

    if (_filtro == _GastosPeriodoFiltro.personalizado) {
      _pickPeriod();
      return;
    }

    if (_startOfDay(next).isAfter(_startOfDay(now))) return;
    setState(() => _referencia = next);
    _load();
  }

  Future<void> _abrirCadastro({GastoResumo? gasto}) async {
    final saved = await showModalBottomSheet<GastoResumo>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _NovoGastoSheet(gasto: gasto),
    );
    if (saved != null) _upsertGastoLocal(saved, replacingId: gasto?.id);
  }

  Future<void> _excluirGasto(GastoResumo gasto) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir gasto'),
        content: Text('Deseja excluir "${gasto.descricao}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD94D4D),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final usuario = ref.read(authSessionProvider);
    if (usuario?.accessToken?.isEmpty != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre novamente para excluir o gasto.')),
      );
      return;
    }

    try {
      await ref.read(apiClientProvider).removerGasto(
            id: gasto.id,
            accessToken: usuario!.accessToken!,
          );
      _removeGastoLocal(gasto.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto excluido.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel excluir o gasto.')),
      );
    }
  }

  void _upsertGastoLocal(GastoResumo gasto, {String? replacingId}) {
    final dados = _dados;
    if (dados == null) {
      _load();
      return;
    }

    final range = _rangeAtual();
    final inRange =
        !_startOfDay(gasto.dataGasto).isBefore(_startOfDay(range.start)) &&
            !_startOfDay(gasto.dataGasto).isAfter(_startOfDay(range.end));
    final gastos = List<GastoResumo>.from(dados.gastos);
    final index =
        gastos.indexWhere((item) => item.id == (replacingId ?? gasto.id));
    final oldValue = index >= 0 ? gastos[index].valor : 0.0;

    if (inRange) {
      if (index >= 0) {
        gastos[index] = gasto;
      } else {
        gastos.add(gasto);
      }
    } else if (index >= 0) {
      gastos.removeAt(index);
    }

    gastos.sort(_compareGastos);
    final newTotal = dados.total - oldValue + (inRange ? gasto.valor : 0.0);
    setState(() {
      _dados = dados.copyWith(gastos: gastos, total: newTotal);
    });
  }

  void _removeGastoLocal(String id) {
    final dados = _dados;
    if (dados == null) return;
    final gastos = List<GastoResumo>.from(dados.gastos);
    final index = gastos.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final removed = gastos.removeAt(index);
    setState(() {
      _dados = dados.copyWith(
        gastos: gastos,
        total: dados.total - removed.valor,
      );
    });
  }

  Future<void> _exportSpreadsheet() async {
    final dados = _dados;
    if (dados == null || dados.gastos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao ha gastos para exportar.')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final range = _rangeAtual();
      final fileName =
          'gastos-${_isoDate(range.start)}-a-${_isoDate(range.end)}.xls';
      final html = _buildStyledSpreadsheet(
        gastos: dados.gastos,
        total: dados.total,
        periodo: _periodLabel(range, _filtro),
      );
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(html)),
            name: fileName,
            mimeType: 'application/vnd.ms-excel',
          ),
        ],
        text: 'Planilha de gastos do periodo ${_periodLabel(range, _filtro)}.',
        subject: 'Gastos da ficha',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planilha pronta para compartilhar.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel compartilhar a planilha.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;
    final gastos = dados?.gastos ?? const <GastoResumo>[];

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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: 'Gastos',
                      onBack: () => context.go(
                        routeWithCurrentOrigin(context, '/monitoramento'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ResumoGastosCard(
                      total: dados?.total ?? 0,
                      periodo: _periodLabel(_rangeAtual(), _filtro),
                    ),
                    const SizedBox(height: 12),
                    _FiltroTabs(
                      selected: _filtro,
                      onChanged: _changeFilter,
                    ),
                    const SizedBox(height: 10),
                    _PeriodSelector(
                      label: _periodLabel(_rangeAtual(), _filtro),
                      onPrevious: () => _movePeriod(-1),
                      onNext: () => _movePeriod(1),
                      onPick: _pickPeriod,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF2BA8BA),
                              ),
                            )
                          : _error != null
                              ? _GastosError(message: _error!, onRetry: _load)
                              : gastos.isEmpty
                                  ? const _GastosEmpty()
                                  : ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      itemCount: gastos.length,
                                      itemBuilder: (context, index) =>
                                          _GastoCard(
                                        gasto: gastos[index],
                                        onEdit: () => _abrirCadastro(
                                          gasto: gastos[index],
                                        ),
                                        onDelete: () => _excluirGasto(
                                          gastos[index],
                                        ),
                                      ),
                                    ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _exporting ? null : _exportSpreadsheet,
                        icon: _exporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.table_chart_rounded),
                        label: const Text('Gerar planilha'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: adaptive(
                            context,
                            const Color(0xFF073248),
                            AppDarkColors.textPrimary,
                          ),
                          side: const BorderSide(color: Color(0xFF2BA8BA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _abrirCadastro,
                        icon: const Icon(Icons.add_rounded, size: 26),
                        label: const Text('Adicionar gasto'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3CB1C3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
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

class _NovoGastoSheet extends ConsumerStatefulWidget {
  const _NovoGastoSheet({this.gasto});

  final GastoResumo? gasto;

  @override
  ConsumerState<_NovoGastoSheet> createState() => _NovoGastoSheetState();
}

class _NovoGastoSheetState extends ConsumerState<_NovoGastoSheet> {
  late final TextEditingController _valorController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _fonteController;
  late DateTime _data;
  bool _saving = false;

  bool get _editing => widget.gasto != null;

  @override
  void initState() {
    super.initState();
    final gasto = widget.gasto;
    _valorController = TextEditingController(
      text: gasto == null
          ? ''
          : gasto.valor.toStringAsFixed(2).replaceAll('.', ','),
    );
    _descricaoController = TextEditingController(text: gasto?.descricao ?? '');
    _fonteController = TextEditingController(text: gasto?.fonte ?? '');
    _data = gasto?.dataGasto ?? DateTime.now();
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    _fonteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDate: _data.isAfter(now) ? now : _data,
    );
    if (selected != null) setState(() => _data = selected);
  }

  Future<void> _save() async {
    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);
    final valor = _parseMoney(_valorController.text);
    final descricao = _descricaoController.text.trim();
    final fonte = _fonteController.text.trim();

    if (idoso == null || usuario?.accessToken?.isEmpty != false) return;
    if (valor == null || valor <= 0 || descricao.isEmpty || fonte.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha valor, descricao e fonte do dinheiro.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final gasto = _editing
          ? await api.atualizarGasto(
              id: widget.gasto!.id,
              valor: valor,
              descricao: descricao,
              fonte: fonte,
              dataGasto: _isoDate(_data),
              accessToken: usuario!.accessToken!,
            )
          : await api.criarGasto(
              idosoId: idoso.id,
              valor: valor,
              descricao: descricao,
              fonte: fonte,
              dataGasto: _isoDate(_data),
              accessToken: usuario!.accessToken!,
            );
      if (!mounted) return;
      Navigator.of(context).pop(gasto);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel salvar o gasto.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _editing ? 'Editar gasto' : 'Novo gasto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(
                    context,
                    const Color(0xFF073248),
                    AppDarkColors.textPrimary,
                  ),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Data: ${_formatDate(_data)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adaptive(
                    context,
                    const Color(0xFF66777D),
                    AppDarkColors.textSecondary,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _GastoInput(
                controller: _valorController,
                label: 'Valor (R\$)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _GastoInput(
                controller: _descricaoController,
                label: 'Descricao',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              _GastoInput(
                controller: _fonteController,
                label: 'Fonte do dinheiro',
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Alterar data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: adaptive(
                    context,
                    const Color(0xFF073248),
                    AppDarkColors.textPrimary,
                  ),
                  side: const BorderSide(color: Color(0xFF2BA8BA)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3CB1C3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(_saving
                      ? 'Salvando...'
                      : _editing
                          ? 'Salvar alteracoes'
                          : 'Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumoGastosCard extends StatelessWidget {
  const _ResumoGastosCard({required this.total, required this.periodo});

  final double total;
  final String periodo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003B4F), Color(0xFF2BA8BA)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E6F7E).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total de gastos',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatCurrency(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  periodo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _FiltroTabs extends StatelessWidget {
  const _FiltroTabs({required this.selected, required this.onChanged});

  final _GastosPeriodoFiltro selected;
  final ValueChanged<_GastosPeriodoFiltro> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (_GastosPeriodoFiltro.dia, 'Diario'),
      (_GastosPeriodoFiltro.semana, 'Semana'),
      (_GastosPeriodoFiltro.mes, 'Mes'),
      (_GastosPeriodoFiltro.ano, 'Ano'),
      (_GastosPeriodoFiltro.personalizado, 'Periodo'),
    ];

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: adaptive(
          context,
          const Color(0xFFBEE4E9),
          AppDarkColors.surfaceAlt,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(option.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  color: selected == option.$1
                      ? const Color(0xFF007986)
                      : Colors.transparent,
                  child: Text(
                    option.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected == option.$1
                          ? Colors.white
                          : adaptive(
                              context,
                              const Color(0xFF073248),
                              AppDarkColors.textPrimary,
                            ),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          color: adaptive(
            context,
            const Color(0xFF0A7D8D),
            AppDarkColors.textPrimary,
          ),
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: adaptive(
                  context, const Color(0xFF073248), AppDarkColors.textPrimary),
              side: const BorderSide(color: Color(0xFF2BA8BA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: adaptive(
            context,
            const Color(0xFF0A7D8D),
            AppDarkColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _GastoCard extends StatelessWidget {
  const _GastoCard({
    required this.gasto,
    required this.onEdit,
    required this.onDelete,
  });

  final GastoResumo gasto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: adaptive(
                  context, const Color(0xFFD5EEF3), AppDarkColors.tintedInfo),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF0A8799),
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gasto.descricao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Fonte: ${gasto.fonte}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF6A7B80),
                        AppDarkColors.textSecondary),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (gasto.criadoPorNome?.trim().isNotEmpty == true)
                  Text(
                    'Registrado por ${gasto.criadoPorNome}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF8A8A8A),
                          AppDarkColors.textMuted),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(gasto.valor),
                style: const TextStyle(
                  color: Color(0xFFD94D4D),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatDate(gasto.dataGasto),
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF8A8A8A),
                      AppDarkColors.textMuted),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'editar') onEdit();
              if (value == 'excluir') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'editar',
                child: Text('Editar'),
              ),
              PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir'),
              ),
            ],
            icon: Icon(
              Icons.more_vert_rounded,
              color: adaptive(
                context,
                const Color(0xFF66777D),
                AppDarkColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GastoInput extends StatelessWidget {
  const _GastoInput({
    required this.controller,
    required this.label,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: adaptive(context, Colors.white, AppDarkColors.surface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFB8E2E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFB8E2E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF2BA8BA), width: 1.4),
        ),
      ),
    );
  }
}

class _GastosEmpty extends StatelessWidget {
  const _GastosEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Nenhum gasto no periodo selecionado.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: adaptive(
              context, const Color(0xFF777777), AppDarkColors.textSecondary),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GastosError extends StatelessWidget {
  const _GastosError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC0392B)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

String _buildStyledSpreadsheet({
  required List<GastoResumo> gastos,
  required double total,
  required String periodo,
}) {
  final rows = gastos.map((gasto) {
    return '''
      <tr>
        <td>${_escapeHtml(_formatDate(gasto.dataGasto))}</td>
        <td class="money">${_escapeHtml(_formatCurrency(gasto.valor))}</td>
        <td>${_escapeHtml(gasto.descricao)}</td>
        <td>${_escapeHtml(gasto.fonte)}</td>
        <td>${_escapeHtml(gasto.criadoPorNome ?? '')}</td>
        <td>${_escapeHtml('${_formatDate(gasto.criadoEm)} ${_formatTime(gasto.criadoEm)}')}</td>
      </tr>
    ''';
  }).join();

  return '''
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8">
        <style>
          body {
            font-family: Arial, sans-serif;
            color: #17324D;
          }
          .summary {
            background: #E8F6F8;
            border: 1px solid #9AD6DE;
            padding: 16px;
            margin-bottom: 16px;
          }
          .brand {
            color: #3396A8;
            font-size: 26px;
            font-weight: 700;
          }
          .total {
            color: #D94D4D;
            font-size: 22px;
            font-weight: 700;
          }
          table {
            border-collapse: collapse;
            width: 100%;
          }
          th {
            background: #3396A8;
            color: #FFFFFF;
            font-weight: 700;
            border: 1px solid #2B8796;
            padding: 10px;
            text-align: left;
          }
          td {
            border: 1px solid #D9E8EB;
            padding: 9px;
          }
          tr:nth-child(even) {
            background: #F6FAFB;
          }
          .money {
            color: #D94D4D;
            font-weight: 700;
          }
        </style>
      </head>
      <body>
        <div class="summary">
          <div class="brand">Ello - Gastos da ficha</div>
          <div>Periodo: ${_escapeHtml(periodo)}</div>
          <div class="total">Total: ${_escapeHtml(_formatCurrency(total))}</div>
        </div>
        <table>
          <thead>
            <tr>
              <th>Data</th>
              <th>Valor</th>
              <th>Descricao</th>
              <th>Fonte</th>
              <th>Registrado por</th>
              <th>Criado em</th>
            </tr>
          </thead>
          <tbody>
            $rows
          </tbody>
        </table>
      </body>
    </html>
  ''';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

double? _parseMoney(String value) {
  final raw = value.trim().replaceAll(' ', '');
  if (raw.isEmpty) return null;
  if (raw.contains(',')) {
    return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));
  }
  return double.tryParse(raw);
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59);

String _isoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _formatCurrency(double value) {
  final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
  final parts = fixed.split(',');
  final number = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < number.length; i++) {
    final position = number.length - i;
    buffer.write(number[i]);
    if (position > 1 && position % 3 == 1) buffer.write('.');
  }
  return 'R\$ ${buffer.toString()},${parts.last}';
}

int _compareGastos(GastoResumo left, GastoResumo right) {
  final dateCompare = right.dataGasto.compareTo(left.dataGasto);
  if (dateCompare != 0) return dateCompare;
  return right.criadoEm.compareTo(left.criadoEm);
}

String _periodLabel(DateTimeRange range, _GastosPeriodoFiltro filtro) {
  return switch (filtro) {
    _GastosPeriodoFiltro.dia => _formatDate(range.start),
    _GastosPeriodoFiltro.semana =>
      '${_formatDate(range.start)} a ${_formatDate(range.end)}',
    _GastosPeriodoFiltro.mes =>
      '${_monthName(range.start.month)} de ${range.start.year}',
    _GastosPeriodoFiltro.ano => '${range.start.year}',
    _GastosPeriodoFiltro.personalizado =>
      '${_formatDate(range.start)} a ${_formatDate(range.end)}',
  };
}

String _monthName(int month) {
  const names = [
    'Janeiro',
    'Fevereiro',
    'Marco',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return names[month - 1];
}
