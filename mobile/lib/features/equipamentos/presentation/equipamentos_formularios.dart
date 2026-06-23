part of 'equipamentos_page.dart';

class _EquipamentoForm extends StatefulWidget {
  const _EquipamentoForm({
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool saving;
  final VoidCallback onCancel;
  final ValueChanged<EquipamentoFormData> onSubmit;

  @override
  State<_EquipamentoForm> createState() => _EquipamentoFormState();
}

class _EquipamentoFormState extends State<_EquipamentoForm> {
  final _nome = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _dataCompra = TextEditingController();
  final _validade = TextEditingController();
  final _ultimaManutencao = TextEditingController();
  final _frequencia = TextEditingController();
  final _local = TextEditingController();
  final _manual = TextEditingController(text: 'manual.pdf');
  final _observacoes = TextEditingController();

  DateTime? _dataCompraValue;
  DateTime? _validadeValue;
  DateTime? _ultimaValue;

  @override
  void dispose() {
    _nome.dispose();
    _marca.dispose();
    _modelo.dispose();
    _dataCompra.dispose();
    _validade.dispose();
    _ultimaManutencao.dispose();
    _frequencia.dispose();
    _local.dispose();
    _manual.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    TextEditingController controller,
    ValueChanged<DateTime> onPicked,
  ) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
      initialDate: now,
    );
    if (selected == null) return;
    controller.text = formatDate(selected);
    onPicked(selected);
  }

  void _submit() {
    if (_nome.text.trim().isEmpty) return;
    final frequencia = int.tryParse(_frequencia.text.trim());
    widget.onSubmit(
      EquipamentoFormData(
        nome: _nome.text.trim(),
        marca: _marca.text.trim(),
        modelo: _modelo.text.trim(),
        dataAquisicao: _dataCompraValue,
        validade: _validadeValue,
        ultimaManutencaoEm: _ultimaValue,
        frequenciaManutencaoDias: frequencia,
        localGuardado: _local.text.trim(),
        urlManual: _manual.text.trim(),
        observacoesSeguranca: _observacoes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      children: [
        const Text(
          'Novo equipamento',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF073248),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _LabeledField(label: 'Nome', controller: _nome),
        Row(
          children: [
            Expanded(child: _LabeledField(label: 'Marca', controller: _marca)),
            const SizedBox(width: 8),
            Expanded(
                child: _LabeledField(label: 'Modelo', controller: _modelo)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Data de compra',
                controller: _dataCompra,
                onTap: () => _pickDate(
                  _dataCompra,
                  (date) => _dataCompraValue = date,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DateField(
                label: 'Validade',
                controller: _validade,
                onTap: () =>
                    _pickDate(_validade, (date) => _validadeValue = date),
              ),
            ),
          ],
        ),
        _DateField(
          label: 'Ultima manutencao',
          controller: _ultimaManutencao,
          onTap: () =>
              _pickDate(_ultimaManutencao, (date) => _ultimaValue = date),
        ),
        _LabeledField(
          label: 'Frequencia de manutencao',
          controller: _frequencia,
          keyboardType: TextInputType.number,
          suffix: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        _LabeledField(label: 'Local onde e guardado', controller: _local),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.attach_file_rounded, size: 20),
                label: const Text('Anexar manual'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF178FA1),
                  side: const BorderSide(color: Color(0xFF38AFC0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFA9D9E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _manual.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF073248),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        _LabeledField(
          label: 'Observacoes',
          controller: _observacoes,
          maxLines: 6,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: FilledButton(
            onPressed: widget.saving ? null : _submit,
            style: _primaryButtonStyle(),
            child: widget.saving
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
      ],
    );
  }
}

class _EquipamentoDetails extends StatelessWidget {
  const _EquipamentoDetails({
    required this.equipamento,
    required this.manutencoes,
    required this.saving,
    required this.onRegister,
    required this.onOutOfUse,
  });

  final Equipamento equipamento;
  final List<ManutencaoEquipamento> manutencoes;
  final bool saving;
  final VoidCallback onRegister;
  final VoidCallback onOutOfUse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Detalhes do equipamento',
          style: TextStyle(
            color: Color(0xFF073248),
            fontSize: 21,
            fontWeight: FontWeight.w900,
            height: 0.9,
          ),
        ),
        const Text(
          'Acompanhe informacoes, historico e ocorrencias',
          style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 10),
        ),
        const SizedBox(height: 9),
        _DetailsHeader(equipamento: equipamento),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.calendar_month_rounded,
                label: 'Ultima manutencao',
                value: formatDate(equipamento.ultimaManutencaoEm),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoTile(
                icon: Icons.build_rounded,
                label: 'Proxima manutencao',
                value: formatDate(equipamento.proximaManutencaoEm),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Historico de manutencoes',
          style: TextStyle(
            color: Color(0xFF073248),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: manutencoes.isEmpty
              ? const _MessageState(
                  icon: Icons.history_rounded,
                  title: 'Sem historico',
                  message: 'Registre a primeira manutencao.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 10),
                  itemCount: manutencoes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _MaintenanceEntry(
                    manutencao: manutencoes[index],
                  ),
                ),
        ),
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: saving ? null : onRegister,
            icon: const Icon(Icons.build_rounded, size: 18),
            label: const Text('Registrar manutencao'),
            style: _primaryButtonStyle(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: saving ? null : onOutOfUse,
            icon: const Icon(Icons.block_rounded, size: 18),
            label: const Text('Marcar como fora de uso'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF003B4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Editar'),
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(0xFFC7C7C7),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ManutencaoForm extends StatefulWidget {
  const _ManutencaoForm({
    required this.equipamento,
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
  });

  final Equipamento equipamento;
  final bool saving;
  final VoidCallback onCancel;
  final ValueChanged<ManutencaoFormData> onSubmit;

  @override
  State<_ManutencaoForm> createState() => _ManutencaoFormState();
}

class _ManutencaoFormState extends State<_ManutencaoForm> {
  final _data = TextEditingController();
  final _servico = TextEditingController();
  final _problema = TextEditingController();
  final _pecas = TextEditingController();
  final _profissional = TextEditingController();
  final _custo = TextEditingController();
  String _tipo = 'Preventiva';
  DateTime? _dataValue;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataValue = now;
    _data.text = formatDate(now);
  }

  @override
  void dispose() {
    _data.dispose();
    _servico.dispose();
    _problema.dispose();
    _pecas.dispose();
    _profissional.dispose();
    _custo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: _dataValue ?? now,
    );
    if (selected == null) return;
    setState(() {
      _dataValue = selected;
      _data.text = formatDate(selected);
    });
  }

  void _submit() {
    final date = _dataValue;
    if (date == null) return;
    widget.onSubmit(
      ManutencaoFormData(
        dataManutencao: date,
        tipoManutencao: _tipo,
        descricaoServico: _servico.text.trim(),
        problemaRelatado: _problema.text.trim(),
        pecasTrocadas: _pecas.text.trim(),
        profissionalEmpresa: _profissional.text.trim(),
        custo: double.tryParse(_custo.text.trim().replaceAll(',', '.')),
        proximaManutencaoEm: nextMaintenanceDate(
          date,
          widget.equipamento.frequenciaManutencaoDias,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
      children: [
        const Text(
          'Registrar manutencao',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        const Text('Equipamento', style: TextStyle(fontSize: 10)),
        Row(
          children: [
            _EquipmentPicture(equipamento: widget.equipamento, size: 34),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                widget.equipamento.nome,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        _DateField(
            label: 'Data da manutencao', controller: _data, onTap: _pickDate),
        const Text('Tipo de manutencao', style: TextStyle(fontSize: 10)),
        Row(
          children: [
            Expanded(
              child: _TypeChip(
                label: 'Preventiva',
                selected: _tipo == 'Preventiva',
                onTap: () => setState(() => _tipo = 'Preventiva'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeChip(
                label: 'Corretiva',
                selected: _tipo == 'Corretiva',
                onTap: () => setState(() => _tipo = 'Corretiva'),
              ),
            ),
          ],
        ),
        _LabeledField(label: 'Servico realizado', controller: _servico),
        _LabeledField(label: 'Problema (opcional)', controller: _problema),
        _LabeledField(label: 'Pecas trocadas (opcional)', controller: _pecas),
        _LabeledField(
          label: 'Profissional/empresa responsavel',
          controller: _profissional,
        ),
        _LabeledField(
          label: 'Custo (opcional)',
          controller: _custo,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 42,
          child: FilledButton(
            onPressed: widget.saving ? null : _submit,
            style: _primaryButtonStyle(),
            child: widget.saving
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
          height: 42,
          child: OutlinedButton(
            onPressed: widget.saving ? null : widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF003B4F),
              side: const BorderSide(color: Color(0xFF38AFC0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }
}
