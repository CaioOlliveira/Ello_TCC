import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/navigation/module_navigation.dart';
import '../../../shared/widgets/module_header.dart';

enum _HistoricoPeriodo { dia, semana, mes }

class HistoricoPage extends ConsumerStatefulWidget {
  const HistoricoPage({required this.tipo, super.key});

  final String tipo;

  @override
  ConsumerState<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends ConsumerState<HistoricoPage> {
  _HistoricoPeriodo _periodo = _HistoricoPeriodo.dia;
  DateTime _referencia = DateTime.now();
  List<HistoricoRegistro> _registros = const [];
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

    final range = _rangeFor(_periodo, _referencia);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ref.read(apiClientProvider).listarHistorico(
            tipo: widget.tipo,
            idosoId: idoso.id,
            inicio: _isoDate(range.$1),
            fim: _isoDate(range.$2),
          );
      if (!mounted) return;
      setState(() => _registros = data);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar o histórico.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDate: _referencia.isAfter(now) ? now : _referencia,
    );
    if (selected == null) return;
    setState(() => _referencia = selected);
    _load();
  }

  void _changePeriod(_HistoricoPeriodo periodo) {
    if (_periodo == periodo) return;
    setState(() {
      _periodo = periodo;
      final now = DateTime.now();
      if (_referencia.isAfter(now)) _referencia = now;
    });
    _load();
  }

  void _movePeriod(int direction) {
    final now = DateTime.now();
    final next = switch (_periodo) {
      _HistoricoPeriodo.dia => DateTime(
          _referencia.year,
          _referencia.month,
          _referencia.day + direction,
        ),
      _HistoricoPeriodo.semana => DateTime(
          _referencia.year,
          _referencia.month,
          _referencia.day + (7 * direction),
        ),
      _HistoricoPeriodo.mes => DateTime(
          _referencia.year,
          _referencia.month + direction,
          1,
        ),
    };
    if (_startOfDay(next).isAfter(_startOfDay(now))) return;
    setState(() => _referencia = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final config = _HistoricoConfig.fromTipo(widget.tipo);

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ModuleHeader(
                    title: config.title,
                    showWordmark: true,
                    onBack: () => context.go(
                      routeWithCurrentOrigin(
                        context,
                        _moduleRouteForTipo(widget.tipo),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PeriodTabs(
                    selected: _periodo,
                    onChanged: _changePeriod,
                  ),
                  const SizedBox(height: 12),
                  _PeriodSelector(
                    label: _periodLabel(_periodo, _referencia),
                    onPrevious: () => _movePeriod(-1),
                    onNext: () => _movePeriod(1),
                    onPick: _selectDate,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2BA8BA),
                            ),
                          )
                        : _error != null
                            ? _HistoricoError(
                                message: _error!,
                                onRetry: _load,
                              )
                            : _registros.isEmpty
                                ? _HistoricoEmpty(config: config)
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 78),
                                    itemCount: _registros.length,
                                    itemBuilder: (context, index) {
                                      final registro = _registros[index];
                                      return _HistoricoCard(
                                        registro: registro,
                                        config: config,
                                      );
                                    },
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

String _moduleRouteForTipo(String tipo) {
  return switch (tipo) {
    'alimentacao' => '/alimentacao',
    'humor' => '/humor',
    _ => '/insumos',
  };
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final _HistoricoPeriodo selected;
  final ValueChanged<_HistoricoPeriodo> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (_HistoricoPeriodo.dia, 'Dia'),
      (_HistoricoPeriodo.semana, 'Semanal'),
      (_HistoricoPeriodo.mes, 'Mês'),
    ];

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF9AD6DE),
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
                    style: TextStyle(
                      color: selected == option.$1
                          ? Colors.white
                          : const Color(0xFF073248),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
          color: const Color(0xFF0A7D8D),
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
          color: const Color(0xFF0A7D8D),
        ),
      ],
    );
  }
}

class _HistoricoCard extends StatelessWidget {
  const _HistoricoCard({required this.registro, required this.config});

  final HistoricoRegistro registro;
  final _HistoricoConfig config;

  @override
  Widget build(BuildContext context) {
    final label = config.actionLabel(registro);
    final tag = config.tag(registro);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: adaptive(
                  context, const Color(0xFFD5EEF3), AppDarkColors.tintedInfo),
              shape: BoxShape.circle,
            ),
            child: Icon(
              config.icon(registro),
              color: const Color(0xFF0A8799),
              size: 31,
            ),
          ),
          const SizedBox(width: 12),
          Container(
              width: 1,
              height: 56,
              color: adaptive(
                  context, const Color(0xFFD0D0D0), AppDarkColors.divider)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_firstName(registro.usuarioNome)} $label',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(
                        context, Colors.black, AppDarkColors.textPrimary),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.detail(registro),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF868686),
                        AppDarkColors.textSecondary),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
              width: 1,
              height: 56,
              color: adaptive(
                  context, const Color(0xFFD0D0D0), AppDarkColors.divider)),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(registro.criadoEm.toLocal()),
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF8A8A8A),
                        AppDarkColors.textMuted),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTime(registro.criadoEm.toLocal()),
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF073248),
                        AppDarkColors.textPrimary),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _Tag(label: tag.$1, color: tag.$2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoricoConfig {
  const _HistoricoConfig({
    required this.title,
    required this.emptyMessage,
    required this.icon,
    required this.actionLabel,
    required this.detail,
    required this.tag,
  });

  final String title;
  final String emptyMessage;
  final IconData Function(HistoricoRegistro registro) icon;
  final String Function(HistoricoRegistro registro) actionLabel;
  final String Function(HistoricoRegistro registro) detail;
  final (String, Color) Function(HistoricoRegistro registro) tag;

  static _HistoricoConfig fromTipo(String tipo) {
    return switch (tipo) {
      'alimentacao' => _alimentacao,
      'humor' => _humor,
      _ => _insumos,
    };
  }
}

final _insumos = _HistoricoConfig(
  title: 'Histórico dos insumos',
  emptyMessage: 'Nenhuma movimentação de insumo neste período.',
  icon: (registro) {
    final tipo = registro.dadosNovos['tipo']?.toString();
    if (tipo == 'saida') return Icons.remove_circle_outline_rounded;
    if (tipo == 'entrada') return Icons.check_circle_outline_rounded;
    if (registro.acao == 'atualizar') return Icons.edit_outlined;
    return Icons.inventory_2_outlined;
  },
  actionLabel: (registro) {
    final tipo = registro.dadosNovos['tipo']?.toString();
    if (registro.acao == 'movimentar_estoque' && tipo == 'saida') {
      return 'deu baixa no estoque';
    }
    if (registro.acao == 'movimentar_estoque' && tipo == 'entrada') {
      return 'adicionou unidades';
    }
    if (registro.acao == 'criar') return 'cadastrou insumo';
    if (registro.acao == 'remover') return 'removeu insumo';
    return 'atualizou insumo';
  },
  detail: (registro) {
    final quantidade = registro.dadosNovos['quantidade']?.toString();
    final item = registro.itemNome;
    if (quantidade != null && quantidade.isNotEmpty) {
      return '$item - $quantidade unidade(s)';
    }
    return item;
  },
  tag: (registro) {
    final tipo = registro.dadosNovos['tipo']?.toString();
    if (tipo == 'saida') return ('Baixa', const Color(0xFFE85D75));
    if (tipo == 'entrada') return ('Verificado', const Color(0xFF27B35F));
    if (registro.acao == 'criar') {
      return ('Registrado', const Color(0xFF4E88C7));
    }
    return ('Atualizado', const Color(0xFF8C52D6));
  },
);

final _alimentacao = _HistoricoConfig(
  title: 'Histórico da alimentação',
  emptyMessage: 'Nenhuma alteração de alimentação neste período.',
  icon: (registro) {
    if (registro.acao == 'concluir') return Icons.restaurant_rounded;
    if (registro.acao == 'atualizar') return Icons.edit_outlined;
    return Icons.local_cafe_outlined;
  },
  actionLabel: (registro) {
    if (registro.acao == 'concluir') return 'marcou refeição completa';
    if (registro.acao == 'atualizar') return 'atualizou refeição';
    if (registro.acao == 'remover') return 'removeu refeição';
    return 'registrou refeição';
  },
  detail: (registro) {
    final alimentos = registro.dadosNovos['alimentos'];
    if (alimentos is List && alimentos.isNotEmpty) {
      final nomes = alimentos
          .whereType<Map>()
          .map((item) => item['nome']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .join(', ');
      if (nomes.isNotEmpty) return '${registro.itemNome}\n$nomes';
    }
    return registro.itemNome;
  },
  tag: (registro) {
    if (registro.acao == 'atualizar') {
      return ('Atualizado', const Color(0xFF8C52D6));
    }
    return ('Registrado', const Color(0xFF27B35F));
  },
);

final _humor = _HistoricoConfig(
  title: 'Histórico de humor',
  emptyMessage: 'Nenhum humor registrado neste período.',
  icon: (registro) => switch (registro.itemNome.toLowerCase()) {
    'calma' || 'calmo' => Icons.sentiment_neutral_rounded,
    'triste' => Icons.sentiment_dissatisfied_rounded,
    'chorona' || 'chorão' => Icons.sentiment_very_dissatisfied_rounded,
    'irritada' || 'irritado' => Icons.mood_bad_rounded,
    'sonolenta' || 'sonolento' => Icons.nights_stay_rounded,
    _ => Icons.sentiment_satisfied_alt_rounded,
  },
  actionLabel: (registro) {
    if (registro.acao == 'atualizar') return 'alterou humor';
    return 'registrou humor';
  },
  detail: (registro) => 'Humor: ${registro.itemNome}',
  tag: (registro) {
    if (registro.acao == 'atualizar') {
      return ('Atualizado', const Color(0xFF8C52D6));
    }
    return ('Registrado', const Color(0xFF4E88C7));
  },
);

class _HistoricoEmpty extends StatelessWidget {
  const _HistoricoEmpty({required this.config});

  final _HistoricoConfig config;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        config.emptyMessage,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: adaptive(
                context, const Color(0xFF777777), AppDarkColors.textSecondary),
            fontSize: 14),
      ),
    );
  }
}

class _HistoricoError extends StatelessWidget {
  const _HistoricoError({required this.message, required this.onRetry});

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

(DateTime, DateTime) _rangeFor(_HistoricoPeriodo periodo, DateTime reference) {
  final normalized = _startOfDay(reference);
  return switch (periodo) {
    _HistoricoPeriodo.dia => (normalized, normalized),
    _HistoricoPeriodo.semana => (
        normalized.subtract(Duration(days: normalized.weekday - 1)),
        normalized.add(Duration(days: 7 - normalized.weekday)),
      ),
    _HistoricoPeriodo.mes => (
        DateTime(normalized.year, normalized.month),
        DateTime(normalized.year, normalized.month + 1, 0),
      ),
  };
}

String _periodLabel(_HistoricoPeriodo periodo, DateTime reference) {
  final range = _rangeFor(periodo, reference);
  return switch (periodo) {
    _HistoricoPeriodo.dia => _formatDate(range.$1),
    _HistoricoPeriodo.semana =>
      '${_formatDate(range.$1)} a ${_formatDate(range.$2)}',
    _HistoricoPeriodo.mes =>
      '${_monthName(reference.month)} de ${reference.year}',
  };
}

DateTime _startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

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

String _firstName(String nome) {
  final trimmed = nome.trim();
  if (trimmed.isEmpty) return 'Usuário';
  return trimmed.split(RegExp(r'\s+')).first;
}

String _monthName(int month) {
  const names = [
    'Janeiro',
    'Fevereiro',
    'Março',
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
