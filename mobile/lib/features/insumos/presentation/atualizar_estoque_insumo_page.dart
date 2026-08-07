part of 'insumos_page.dart';

class _InsumoStockView extends ConsumerStatefulWidget {
  const _InsumoStockView({
    required this.insumo,
    required this.usuarioId,
    required this.onCancel,
    required this.onSaved,
  });

  final InsumoResumo? insumo;
  final String? usuarioId;
  final VoidCallback onCancel;
  final ValueChanged<InsumoResumo> onSaved;

  @override
  ConsumerState<_InsumoStockView> createState() => _InsumoStockViewState();
}

class _InsumoStockViewState extends ConsumerState<_InsumoStockView> {
  final _nomeController = TextEditingController();
  final _estoqueAtualController = TextEditingController();
  final _quantidadePorUnidadeController = TextEditingController();
  final _minimoController = TextEditingController();
  final _consumoController = TextEditingController();
  final _validadeController = TextEditingController();
  final _diasAlertaValidadeController = TextEditingController();
  final _localController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _adicaoController = TextEditingController();
  final _subtracaoController = TextEditingController();
  final _picker = ImagePicker();

  String _tipoUnidade = 'ml';
  String? _frequenciaUso;
  String? _fotoUrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final insumo = widget.insumo;
    if (insumo == null) return;

    _nomeController.text = insumo.nome;
    _estoqueAtualController.text = _stockLabel(insumo.quantidadeUnidades);
    _tipoUnidade = insumo.tipoUnidade;
    _quantidadePorUnidadeController.text =
        _editableNumber(insumo.quantidadePorUnidade);
    _minimoController.text = _editableNumber(insumo.alertaMinimoUnidades);
    _consumoController.text = _editableNumber(insumo.consumoMedioDiario);
    _diasAlertaValidadeController.text = insumo.diasAlertaValidade.toString();
    _localController.text = insumo.localArmazenamento ?? '';
    _observacoesController.text = insumo.observacoes ?? '';
    _frequenciaUso = insumo.frequenciaUso == 'Eventual'
        ? 'Diario'
        : (insumo.frequenciaUso ?? 'Diario');
    _fotoUrl = insumo.fotoUrl;
    if (insumo.dataValidade != null) {
      _validadeController.text = _formatBrazilianDate(insumo.dataValidade!);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _estoqueAtualController.dispose();
    _quantidadePorUnidadeController.dispose();
    _minimoController.dispose();
    _consumoController.dispose();
    _validadeController.dispose();
    _diasAlertaValidadeController.dispose();
    _localController.dispose();
    _observacoesController.dispose();
    _adicaoController.dispose();
    _subtracaoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = _imageExtension(picked.name);
    setState(() {
      _fotoUrl = 'data:image/$extension;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final currentDate = _parseBrazilianDate(_validadeController.text);
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10),
      initialDate: currentDate != null && !currentDate.isBefore(firstDate)
          ? currentDate
          : now,
    );
    if (selected == null) return;
    _validadeController.text = _formatBrazilianDate(selected);
  }

  Future<void> _save() async {
    final insumo = widget.insumo;
    if (insumo == null) return;

    FocusScope.of(context).unfocus();
    final nome = _nomeController.text.trim();
    final adicao = _toDouble(_adicaoController.text) ?? 0;
    final subtracao = _toDouble(_subtracaoController.text) ?? 0;
    final consumo = _toDouble(_consumoController.text);
    final diasAlerta = int.tryParse(_diasAlertaValidadeController.text.trim());

    if (nome.isEmpty) {
      setState(() => _error = 'Informe o nome do insumo.');
      return;
    }
    if (adicao < 0 || subtracao < 0) {
      setState(() => _error = 'Adição e subtração não podem ser negativas.');
      return;
    }
    if (subtracao >= insumo.quantidadeUnidades + adicao) {
      setState(
        () => _error = 'A subtracao precisa deixar estoque acima de zero.',
      );
      return;
    }
    if (diasAlerta == null || diasAlerta < 0 || diasAlerta > 3650) {
      setState(() => _error = 'Informe um prazo de vencimento valido.');
      return;
    }
    final validade = _parseBrazilianDate(_validadeController.text);
    if (validade != null && _isBeforeToday(validade)) {
      setState(() => _error = 'A validade não pode ser anterior a hoje.');
      return;
    }
    if (consumo != null && consumo > 0 && _frequenciaUso == null) {
      setState(() => _error = 'Selecione a frequencia do consumo.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      var updated = await ref.read(apiClientProvider).atualizarInsumo(
        id: insumo.id,
        data: {
          'nome': nome,
          'tipoUnidade': _tipoUnidade,
          'quantidadePorUnidade':
              _toDouble(_quantidadePorUnidadeController.text),
          'alertaMinimoUnidades': _toDouble(_minimoController.text),
          'consumoMedioDiario': consumo,
          'dataValidade': _toIsoDate(_validadeController.text),
          'diasAlertaValidade': diasAlerta,
          'fotoUrl': _fotoUrl,
          'localArmazenamento': _localController.text.trim().isEmpty
              ? null
              : _localController.text.trim(),
          'frequenciaUso': _frequenciaUso,
          'observacoes': _observacoesController.text.trim().isEmpty
              ? null
              : _observacoesController.text.trim(),
          if (widget.usuarioId != null && widget.usuarioId!.isNotEmpty)
            'usuarioId': widget.usuarioId,
        },
      );

      if (adicao > 0) {
        final movement = await ref.read(apiClientProvider).movimentarInsumo(
              id: insumo.id,
              tipo: 'entrada',
              quantidade: adicao,
              motivo: 'Atualizacao pelo app',
              usuarioId: widget.usuarioId,
            );
        updated = updated.copyWith(
          quantidadeUnidades: movement.quantidadeUnidades,
        );
      }
      if (subtracao > 0) {
        final movement = await ref.read(apiClientProvider).movimentarInsumo(
              id: insumo.id,
              tipo: 'saida',
              quantidade: subtracao,
              motivo: 'Atualizacao pelo app',
              usuarioId: widget.usuarioId,
            );
        updated = updated.copyWith(
          quantidadeUnidades: movement.quantidadeUnidades,
        );
      }

      if (!mounted) return;
      widget.onSaved(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível atualizar o insumo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insumo = widget.insumo;
    if (insumo == null) {
      return _ErrorState(
        message: 'Insumo não encontrado.',
        onRetry: widget.onCancel,
      );
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        18,
        34,
        18,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.onCancel,
              iconSize: 32,
              tooltip: 'Voltar',
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF2CA0B4),
              ),
            ),
          ),
          const Text(
            'Atualizar insumo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF2CA0B4),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  _ProductImage(value: _fotoUrl, size: 88),
                  const SizedBox(height: 6),
                  const Text(
                    'Alterar foto',
                    style: TextStyle(
                      color: Color(0xFF2CA0B4),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _LabeledField(label: 'Nome do insumo', controller: _nomeController),
          const SizedBox(height: 12),
          _UnitSelector(
            selected: _tipoUnidade,
            onChanged: (value) => setState(() => _tipoUnidade = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Conteudo por unidade',
                  controller: _quantidadePorUnidadeController,
                  keyboardType: TextInputType.number,
                  suffixText: _tipoUnidade,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledField(
                  label: 'Estoque atual',
                  controller: _estoqueAtualController,
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StepperField(
                  label: 'Adicionar ao estoque',
                  controller: _adicaoController,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StepperField(
                  label: 'Subtrair do estoque',
                  controller: _subtracaoController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Estoque minimo',
                  controller: _minimoController,
                  keyboardType: TextInputType.number,
                  suffixText: 'unidades',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledField(
                  label: 'Consumo por periodo',
                  controller: _consumoController,
                  keyboardType: TextInputType.number,
                  suffixText: 'unidades',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Data de validade',
                  controller: _validadeController,
                  readOnly: true,
                  onTap: _selectDate,
                  suffixIcon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledField(
                  label: 'Avisar antes do vencimento',
                  controller: _diasAlertaValidadeController,
                  keyboardType: TextInputType.number,
                  suffixText: 'dias',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FrequencySelector(
            value: _frequenciaUso,
            onChanged: (value) => setState(() => _frequenciaUso = value),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Local de armazenamento',
            controller: _localController,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Observacoes',
            controller: _observacoesController,
            minLines: 4,
            maxLines: 4,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: _primaryButtonStyle(context),
              icon: _saving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Salvando...' : 'Salvar alteracoes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperField extends StatefulWidget {
  const _StepperField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  State<_StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<_StepperField> {
  double get _value => _toDouble(widget.controller.text) ?? 0;

  void _setValue(double value) {
    final clamped = value < 0 ? 0.0 : value;
    setState(() {
      widget.controller.text = _editableNumber(clamped);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(widget.label),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: adaptive(context, Colors.white, AppDarkColors.surface),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3BA7B8)),
          ),
          child: Row(
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                onTap: () => _setValue(_value - 1),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF17324D),
                        AppDarkColors.textPrimary),
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add_rounded,
                onTap: () => _setValue(_value + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 46,
        child: Icon(icon, color: const Color(0xFF2CA0B4), size: 20),
      ),
    );
  }
}

String _editableNumber(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');
}
