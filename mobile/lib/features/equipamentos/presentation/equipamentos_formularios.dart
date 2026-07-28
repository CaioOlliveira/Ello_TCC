part of 'equipamentos_page.dart';

class _EquipamentoForm extends StatefulWidget {
  const _EquipamentoForm({
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
    this.initial,
  });

  final bool saving;
  final VoidCallback onCancel;
  final ValueChanged<EquipamentoFormData> onSubmit;
  final Equipamento? initial;

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
  final _manual = TextEditingController();
  final _observacoes = TextEditingController();
  final _imagePicker = ImagePicker();

  DateTime? _dataCompraValue;
  DateTime? _validadeValue;
  DateTime? _ultimaValue;
  int? _frequenciaValue;
  String? _urlFoto;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;

    _nome.text = initial.nome;
    _marca.text = initial.marca;
    _modelo.text = initial.modelo;
    _dataCompraValue = initial.dataAquisicao;
    _validadeValue = initial.validade;
    _ultimaValue = initial.ultimaManutencaoEm;
    _dataCompra.text =
        initial.dataAquisicao == null ? '' : formatDate(initial.dataAquisicao);
    _validade.text =
        initial.validade == null ? '' : formatDate(initial.validade);
    _ultimaManutencao.text = initial.ultimaManutencaoEm == null
        ? ''
        : formatDate(initial.ultimaManutencaoEm);
    _frequenciaValue = initial.frequenciaManutencaoDias;
    _frequencia.text = maintenanceFrequencyLabel(_frequenciaValue);
    _local.text = initial.localGuardado;
    _manual.text = initial.urlManual.trim().toLowerCase() == 'manual.pdf'
        ? ''
        : initial.urlManual;
    _observacoes.text = initial.observacoesSeguranca;
    _urlFoto = initial.urlFoto.isEmpty ? null : initial.urlFoto;
  }

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
      context: Navigator.of(context, rootNavigator: true).context,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
      initialDate: now,
    );
    if (selected == null) return;
    controller.text = formatDate(selected);
    onPicked(selected);
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = _equipmentImageExtension(picked.name);
    setState(() {
      _urlFoto = 'data:image/$extension;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _attachManual() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Selecione o manual em PDF',
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel abrir o seletor de arquivos.'),
        ),
      );
      return;
    }
    if (result == null) return;

    final file = result.files.single;
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um arquivo PDF.')),
      );
      return;
    }

    var bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel ler o PDF.')),
      );
      return;
    }

    final manualBytes = bytes;
    final encodedName = Uri.encodeComponent(file.name);
    setState(() {
      _manual.text =
          'data:application/pdf;name=$encodedName;base64,${base64Encode(manualBytes)}';
    });
  }

  Future<void> _pickFrequency() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: adaptive(context, Colors.white, AppDarkColors.surfaceElevated),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: adaptive(context, const Color(0xFFD0D0D0), AppDarkColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Frequencia de manutencao',
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in maintenanceFrequencyOptions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _frequenciaValue == option.days
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: const Color(0xFF178FA1),
                    ),
                    title: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(option.days),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() {
      _frequenciaValue = selected;
      _frequencia.text = maintenanceFrequencyLabel(selected);
    });
  }

  void _submit() {
    if (_nome.text.trim().isEmpty) return;
    widget.onSubmit(
      EquipamentoFormData(
        nome: _nome.text.trim(),
        marca: _marca.text.trim(),
        modelo: _modelo.text.trim(),
        dataAquisicao: _dataCompraValue,
        validade: _validadeValue,
        ultimaManutencaoEm: _ultimaValue,
        frequenciaManutencaoDias: _frequenciaValue,
        localGuardado: _local.text.trim(),
        urlManual: _manual.text.trim(),
        urlFoto: _urlFoto,
        observacoesSeguranca: _observacoes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      children: [
        Text(
          widget.initial == null ? 'Novo equipamento' : 'Editar equipamento',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
            fontSize: 22,
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
        _OptionField(
          label: 'Frequencia de manutencao',
          controller: _frequencia,
          onTap: _pickFrequency,
        ),
        _LabeledField(label: 'Local onde e guardado', controller: _local),
        const SizedBox(height: 6),
        Text(
          'Foto do equipamento (opcional)',
          style: TextStyle(
            fontSize: 13,
            color: adaptive(context, const Color(0xFF333333), AppDarkColors.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: widget.saving ? null : _pickImage,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: adaptive(context, Colors.white, AppDarkColors.surface),
              border: Border.all(color: const Color(0xFF38AFC0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  color: Color(0xFF178FA1),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _urlFoto == null ? 'Anexar imagem' : 'Imagem anexada',
                    style: TextStyle(
                      color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_urlFoto != null)
                  _EquipmentImagePreview(value: _urlFoto!, size: 42),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.saving ? null : _attachManual,
                icon: const Icon(Icons.attach_file_rounded, size: 22),
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
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFA9D9E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _manual.text.isEmpty
                      ? 'Nenhum manual anexado'
                      : manualDisplayName(_manual.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
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
          height: 48,
          child: FilledButton(
            onPressed: widget.saving ? null : _submit,
            style: _primaryButtonStyle(),
            child: widget.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.initial == null ? 'Salvar' : 'Salvar alteracoes'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: widget.saving ? null : widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: adaptive(context, const Color(0xFF003B4F), AppDarkColors.textPrimary),
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

class _EquipamentoDetails extends StatelessWidget {
  const _EquipamentoDetails({
    required this.equipamento,
    required this.manutencoes,
    required this.saving,
    required this.onRegister,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final Equipamento equipamento;
  final List<ManutencaoEquipamento> manutencoes;
  final bool saving;
  final VoidCallback onRegister;
  final VoidCallback onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Detalhes do equipamento',
                style: TextStyle(
                  color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            PopupMenuButton<String>(
              enabled: !saving,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
                size: 28,
              ),
              onSelected: (value) {
                if (value == 'manutencao') onRegister();
                if (value == 'status') onStatusChanged();
                if (value == 'editar') onEdit();
                if (value == 'excluir') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'manutencao',
                  child: Row(
                    children: [
                      Icon(Icons.build_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Registrar manutencao'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: Row(
                    children: [
                      Icon(
                        equipamento.status == 'Fora de uso'
                            ? Icons.check_circle_rounded
                            : Icons.block_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        equipamento.status == 'Fora de uso'
                            ? 'Colocar em uso'
                            : 'Marcar fora de uso',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'excluir',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Color(0xFFFF1744),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Excluir',
                        style: TextStyle(color: Color(0xFFFF1744)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        Text(
          'Historico de manutencoes',
          style: TextStyle(
            color: adaptive(context, const Color(0xFF073248), AppDarkColors.textPrimary),
            fontSize: 18,
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
                  itemBuilder: (context, index) => StaggeredEntry(
                    index: index,
                    child: _MaintenanceEntry(
                      manutencao: manutencoes[index],
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
      context: Navigator.of(context, rootNavigator: true).context,
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
        Text(
          'Registrar manutencao',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: adaptive(context, const Color(0xFF111111), AppDarkColors.textPrimary),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        const Text('Equipamento', style: TextStyle(fontSize: 13)),
        Row(
          children: [
            _EquipmentPicture(equipamento: widget.equipamento, size: 42),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                widget.equipamento.nome,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        _DateField(
            label: 'Data da manutencao', controller: _data, onTap: _pickDate),
        const Text('Tipo de manutencao', style: TextStyle(fontSize: 13)),
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
          height: 48,
          child: FilledButton(
            onPressed: widget.saving ? null : _submit,
            style: _primaryButtonStyle(),
            child: widget.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
          height: 48,
          child: OutlinedButton(
            onPressed: widget.saving ? null : widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: adaptive(context, const Color(0xFF003B4F), AppDarkColors.textPrimary),
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
