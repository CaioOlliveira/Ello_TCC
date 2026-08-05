part of 'insumos_page.dart';

class _InsumoFormView extends ConsumerStatefulWidget {
  const _InsumoFormView({
    required this.idosoId,
    required this.onCancel,
    required this.onSaved,
  });

  final String idosoId;
  final VoidCallback onCancel;
  final ValueChanged<InsumoResumo> onSaved;

  @override
  ConsumerState<_InsumoFormView> createState() => _InsumoFormViewState();
}

class _InsumoFormViewState extends ConsumerState<_InsumoFormView> {
  final _nomeController = TextEditingController();
  final _quantidadePorUnidadeController = TextEditingController();
  final _estoqueController = TextEditingController();
  final _minimoController = TextEditingController();
  final _validadeController = TextEditingController();
  final _diasAlertaValidadeController = TextEditingController(text: '7');
  final _consumoController = TextEditingController();
  final _localController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _picker = ImagePicker();

  String _tipoUnidade = 'ml';
  String? _frequenciaUso = 'Diario';
  String? _fotoUrl;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nomeController.dispose();
    _quantidadePorUnidadeController.dispose();
    _estoqueController.dispose();
    _minimoController.dispose();
    _validadeController.dispose();
    _diasAlertaValidadeController.dispose();
    _consumoController.dispose();
    _localController.dispose();
    _observacoesController.dispose();
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

  void _removeImage() {
    setState(() => _fotoUrl = null);
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      initialDate: _parseBrazilianDate(_validadeController.text) ?? now,
    );
    if (selected == null) return;
    _validadeController.text = _formatBrazilianDate(selected);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final nome = _nomeController.text.trim();
    final estoque = _toDouble(_estoqueController.text);
    final consumo = _toDouble(_consumoController.text);
    final diasAlerta = int.tryParse(_diasAlertaValidadeController.text.trim());

    if (nome.isEmpty || estoque == null) {
      setState(() => _error = 'Informe nome e estoque atual.');
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
      final usuarioId = ref.read(authSessionProvider)?.id;
      final insumo = await ref.read(apiClientProvider).criarInsumo(
        data: {
          'idosoId': widget.idosoId,
          'nome': nome,
          'tipoUnidade': _tipoUnidade,
          'quantidadeUnidades': estoque,
          if (_toDouble(_quantidadePorUnidadeController.text) != null)
            'quantidadePorUnidade':
                _toDouble(_quantidadePorUnidadeController.text),
          if (_toDouble(_minimoController.text) != null)
            'alertaMinimoUnidades': _toDouble(_minimoController.text),
          if (consumo != null) 'consumoMedioDiario': consumo,
          if (_toIsoDate(_validadeController.text) != null)
            'dataValidade': _toIsoDate(_validadeController.text),
          'diasAlertaValidade': diasAlerta,
          if (_fotoUrl != null) 'fotoUrl': _fotoUrl,
          if (_localController.text.trim().isNotEmpty)
            'localArmazenamento': _localController.text.trim(),
          if (_frequenciaUso != null) 'frequenciaUso': _frequenciaUso,
          if (_observacoesController.text.trim().isNotEmpty)
            'observacoes': _observacoesController.text.trim(),
          if (usuarioId != null && usuarioId.isNotEmpty) 'usuarioId': usuarioId,
        },
      );

      if (!mounted) return;
      widget.onSaved(insumo);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível salvar o insumo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        12,
        28,
        12,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Text(
            'Cadastro de insumos',
            style: TextStyle(
              color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Cadastre itens de uso diario para controlar estoque e validade',
            style: TextStyle(
                color: adaptive(context, const Color(0xFF8A8A8A),
                    AppDarkColors.textSecondary),
                fontSize: 9.5),
          ),
          const SizedBox(height: 14),
          _LabeledField(label: 'Nome do Insumo', controller: _nomeController),
          const SizedBox(height: 9),
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
              const SizedBox(width: 7),
              Expanded(
                child: _LabeledField(
                  label: 'Estoque atual (unidades)',
                  controller: _estoqueController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'Avisar quantos dias antes do vencimento?',
            controller: _diasAlertaValidadeController,
            keyboardType: TextInputType.number,
            suffixText: 'dias',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Estoque minimo para alerta',
                  controller: _minimoController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _LabeledField(
                  label: 'Data de validade',
                  controller: _validadeController,
                  readOnly: true,
                  onTap: _selectDate,
                  suffixIcon: Icons.calendar_month_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Consumo medio por periodo',
                  controller: _consumoController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _FrequencySelector(
                  value: _frequenciaUso,
                  onChanged: (value) => setState(() => _frequenciaUso = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'Local de armazenamento',
            controller: _localController,
          ),
          const SizedBox(height: 12),
          const _FormLabel('Foto do produto (opcional)'),
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: adaptive(context, Colors.white, AppDarkColors.surface),
                border: Border.all(color: const Color(0xFF3BA7B8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    color: Color(0xFF2CA0B4),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fotoUrl == null ? 'Anexar imagem' : 'Imagem anexada',
                      style: TextStyle(
                        color: adaptive(context, const Color(0xFF6B6B6B),
                            AppDarkColors.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_fotoUrl != null)
                    _ProductImage(value: _fotoUrl, size: 28),
                  if (_fotoUrl != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _removeImage,
                      tooltip: 'Remover imagem',
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          _LabeledField(
            label: 'Observacoes',
            controller: _observacoesController,
            minLines: 5,
            maxLines: 5,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 13),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: _primaryButtonStyle(context),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _saving ? null : widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: adaptive(context, const Color(0xFF17324D),
                    AppDarkColors.textPrimary),
                side: const BorderSide(color: Color(0xFF3BA7B8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const units = ['ml', 'L', 'g', 'kg', 'unid.', 'cm'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FormLabel('Unidade'),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              for (final unit in units)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(unit),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == unit
                            ? adaptive(context, const Color(0xFFD6EEF2),
                                AppDarkColors.tintedInfo)
                            : adaptive(
                                context, Colors.white, AppDarkColors.surface),
                        border: Border.all(color: const Color(0xFF3BA7B8)),
                      ),
                      child: Text(
                        unit,
                        style: TextStyle(
                          color: selected == unit
                              ? const Color(0xFF006B7E)
                              : adaptive(context, const Color(0xFF17324D),
                                  AppDarkColors.textPrimary),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FrequencySelector extends StatelessWidget {
  const _FrequencySelector({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FormLabel('Frequencia de uso'),
        SizedBox(
          height: 48,
          child: DropdownButtonFormField<String>(
            initialValue: value,
            onChanged: onChanged,
            decoration: _inputDecoration(context, 'Selecione a frequencia'),
            style: TextStyle(
                color: adaptive(context, const Color(0xFF17324D),
                    AppDarkColors.textPrimary),
                fontSize: 11),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF2CA0B4),
              size: 18,
            ),
            items: const [
              DropdownMenuItem(value: 'Diario', child: Text('Diario')),
              DropdownMenuItem(value: 'Semanal', child: Text('Semanal')),
              DropdownMenuItem(value: 'Mensal', child: Text('Mensal')),
            ],
          ),
        ),
      ],
    );
  }
}
