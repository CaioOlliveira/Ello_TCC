part of 'insumos_page.dart';

class _InsumoDetailView extends StatelessWidget {
  const _InsumoDetailView({
    required this.insumo,
    required this.onBack,
    required this.onAtualizar,
    required this.onDelete,
  });

  final InsumoResumo? insumo;
  final VoidCallback onBack;
  final VoidCallback onAtualizar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final item = insumo;
    if (item == null) {
      return _ErrorState(message: 'Insumo nao encontrado.', onRetry: onBack);
    }

    final status = _statusFor(item);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF2CA0B4),
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Detalhes insumo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF2CA0B4),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 26),
          StaggeredEntry(
            index: 0,
            child: Row(
              children: [
                _ProductImage(value: item.fotoUrl, size: 72),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 11),
                      _StatusBadge(status: status),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          StaggeredEntry(index: 1, child: _DetailPanel(insumo: item)),
          const Spacer(),
          StaggeredEntry(
            index: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: onAtualizar,
                icon: const Icon(Icons.change_circle_rounded, size: 20),
                label: const Text('Atualizar estoque'),
                style: _primaryButtonStyle(context),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Excluir insumo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC0392B),
                side: const BorderSide(color: Color(0xFFC0392B)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.insumo});

  final InsumoResumo insumo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 16, 13, 16),
      decoration: BoxDecoration(
        color: adaptive(context, Colors.white, AppDarkColors.surface),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Estoque atual',
            value: _stockLabel(insumo.quantidadeUnidades),
          ),
          _DetailRow(
            label: 'Conteudo por unidade',
            value: _contentPerUnitLabel(insumo),
          ),
          _DetailRow(
            label: 'Consumo medio',
            value: insumo.consumoMedioDiario == null
                ? 'Nao informado'
                : '${_formatNumber(insumo.consumoMedioDiario!)} un. '
                    '${_frequencySuffix(insumo.frequenciaUso)}',
          ),
          _DetailRow(label: 'Acaba em', value: _forecastLabel(insumo)),
          _DetailRow(
            label: 'Validade',
            value: insumo.dataValidade == null
                ? 'Nao informada'
                : _formatBrazilianDate(insumo.dataValidade!),
          ),
          _DetailRow(
            label: 'Alerta de vencimento',
            value: '${insumo.diasAlertaValidade} dias antes',
          ),
          _DetailRow(
            label: 'Estoque minimo',
            value: insumo.alertaMinimoUnidades == null
                ? 'Nao informado'
                : _stockLabel(insumo.alertaMinimoUnidades!),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Observacoes',
              style: TextStyle(
                color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              insumo.observacoes?.isNotEmpty == true
                  ? insumo.observacoes!
                  : 'Sem observacoes.',
              style: TextStyle(
                color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
