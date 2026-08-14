import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';
import 'agenda_models.dart';
import 'agenda_utils.dart';

class AgendaFormPage extends StatefulWidget {
  const AgendaFormPage({
    required this.selectedDay,
    required this.tags,
    this.initial,
    super.key,
  });

  final DateTime selectedDay;
  final List<String> tags;
  final AgendaCompromisso? initial;

  @override
  State<AgendaFormPage> createState() => _AgendaFormPageState();
}

class _AgendaFormPageState extends State<AgendaFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloController;
  late final TextEditingController _dataController;
  late final TextEditingController _horaController;
  late final TextEditingController _localController;
  late final TextEditingController _observacoesController;
  late List<String> _tags;
  late DateTime _data;
  late TimeOfDay _hora;
  late String _tag;
  late String _frequencia;
  late bool _lembrete;
  late int _antecedenciaMinutos;
  String _status = 'agendado';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _data = initial?.dataHora ?? widget.selectedDay;
    _hora = TimeOfDay.fromDateTime(initial?.dataHora ?? DateTime.now());
    _tags = widget.tags.toSet().toList();
    _tag = initial?.tag ?? (_tags.isEmpty ? 'Consulta' : _tags.first);
    if (!_tags.contains(_tag)) _tags.add(_tag);
    _frequencia = initial?.frequencia ?? 'Semanalmente';
    _lembrete = initial?.ativarLembrete ?? true;
    _antecedenciaMinutos = _normalizeReminderMinutes(
      initial?.antecedenciaLembreteMinutos ?? 30,
    );
    _status = initial?.status == 'cancelado' ? 'cancelado' : 'agendado';

    _tituloController = TextEditingController(text: initial?.titulo);
    _dataController = TextEditingController(text: formatAgendaDate(_data));
    _horaController = TextEditingController(text: formatAgendaTimeOfDay(_hora));
    _localController = TextEditingController(text: initial?.local);
    _observacoesController = TextEditingController(text: initial?.observacoes);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _dataController.dispose();
    _horaController.dispose();
    _localController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() {
      _data = picked;
      _dataController.text = formatAgendaDate(picked);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _hora);
    if (picked == null) return;
    setState(() {
      _hora = picked;
      _horaController.text = formatAgendaTimeOfDay(picked);
    });
  }

  Future<void> _addTag() async {
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => const _AddTagDialog(),
    );

    if (!mounted || tag == null || tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _tag = tag;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final dataHora = DateTime(
      _data.year,
      _data.month,
      _data.day,
      _hora.hour,
      _hora.minute,
    );

    Navigator.of(context).pop(
      AgendaFormResult(
        tags: _tags,
        data: AgendaCompromissoFormData(
          titulo: _tituloController.text.trim(),
          tag: _tag,
          dataHora: dataHora,
          local: _localController.text.trim(),
          frequencia: _frequencia,
          observacoes: _observacoesController.text.trim(),
          ativarLembrete: _lembrete,
          antecedenciaLembreteMinutos: _lembrete ? _antecedenciaMinutos : null,
          status: _status,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.initial == null ? 'Novo compromisso' : 'Editar compromisso';

    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFAFAFA), AppDarkColors.bg),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                children: [
                  AppPageHeader(
                    title: title,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('Titulo'),
                  _AgendaTextField(
                    controller: _tituloController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe o titulo.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const _FormLabel('Tags'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in _tags)
                        ChoiceChip(
                          label: Text(tag),
                          selected: _tag == tag,
                          onSelected: (_) => setState(() => _tag = tag),
                          labelStyle: const TextStyle(fontSize: 11),
                          visualDensity: VisualDensity.compact,
                          selectedColor: agendaTagColor(tag),
                          backgroundColor:
                              agendaTagColor(tag).withValues(alpha: 0.45),
                          side: BorderSide.none,
                        ),
                      OutlinedButton.icon(
                        onPressed: _addTag,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Tag'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 31),
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          foregroundColor: const Color(0xFF1696AA),
                          side: const BorderSide(color: Color(0xFF1696AA)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FormLabel('Data'),
                            _AgendaTextField(
                              controller: _dataController,
                              readOnly: true,
                              suffixIcon: Icons.calendar_month_rounded,
                              onTap: _pickDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FormLabel('Hora'),
                            _AgendaTextField(
                              controller: _horaController,
                              readOnly: true,
                              suffixIcon: Icons.access_time_rounded,
                              onTap: _pickTime,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _FormLabel('Local'),
                  _AgendaTextField(
                    controller: _localController,
                    suffixIcon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 8),
                  const _FormLabel('Frequência'),
                  DropdownButtonFormField<String>(
                    initialValue: _frequencia,
                    decoration: _fieldDecoration(context),
                    items: const [
                      DropdownMenuItem(
                        value: 'Não repetir',
                        child: Text('Não repetir'),
                      ),
                      DropdownMenuItem(
                        value: 'Diariamente',
                        child: Text('Diariamente'),
                      ),
                      DropdownMenuItem(
                        value: 'Semanalmente',
                        child: Text('Semanalmente'),
                      ),
                      DropdownMenuItem(
                        value: 'Mensalmente',
                        child: Text('Mensalmente'),
                      ),
                      DropdownMenuItem(
                        value: 'Anualmente',
                        child: Text('Anualmente'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _frequencia = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  const _FormLabel('Observações'),
                  _AgendaTextField(
                    controller: _observacoesController,
                    minLines: 4,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lembrete',
                              style: TextStyle(
                                color: adaptive(context, Colors.black,
                                    AppDarkColors.textPrimary),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'Ativar lembretes',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _lembrete,
                        activeThumbColor: const Color(0xFF007C8B),
                        onChanged: (value) => setState(() => _lembrete = value),
                      ),
                    ],
                  ),
                  const _FormLabel('Antecedencia do lembrete'),
                  DropdownButtonFormField<int>(
                    initialValue: _antecedenciaMinutos,
                    decoration: _fieldDecoration(
                      context,
                      suffixIcon: Icons.access_time_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 min antes')),
                      DropdownMenuItem(value: 10, child: Text('10 min antes')),
                      DropdownMenuItem(value: 30, child: Text('30 min antes')),
                      DropdownMenuItem(value: 60, child: Text('1 hora antes')),
                      DropdownMenuItem(
                          value: 120, child: Text('2 horas antes')),
                      DropdownMenuItem(value: 1440, child: Text('1 dia antes')),
                    ],
                    onChanged: _lembrete
                        ? (value) {
                            if (value != null) {
                              setState(() => _antecedenciaMinutos = value);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const _FormLabel('Status'),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _fieldDecoration(context),
                    items: const [
                      DropdownMenuItem(
                          value: 'agendado', child: Text('Agendado')),
                      DropdownMenuItem(
                          value: 'cancelado', child: Text('Cancelado')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 43,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF34A4B7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Salvar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF003B4F),
                        side: const BorderSide(color: Color(0xFF003B4F)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Cancelar'),
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

class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog();

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova tag'),
      content: TextField(
        controller: _controller,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome da tag'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _AgendaTextField extends StatelessWidget {
  const _AgendaTextField({
    required this.controller,
    this.validator,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final bool readOnly;
  final IconData? suffixIcon;
  final VoidCallback? onTap;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      minLines: minLines,
      maxLines: maxLines,
      decoration: _fieldDecoration(context, suffixIcon: suffixIcon),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: adaptive(context, Colors.black, AppDarkColors.textPrimary),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, {IconData? suffixIcon}) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: adaptive(context, Colors.white, AppDarkColors.surface),
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    suffixIcon: suffixIcon == null
        ? null
        : Icon(suffixIcon, color: const Color(0xFF1696AA), size: 17),
    suffixIconConstraints: const BoxConstraints(minWidth: 28),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF34A4B7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF34A4B7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF007C8B), width: 1.5),
    ),
  );
}

int _normalizeReminderMinutes(int value) {
  const options = [5, 10, 30, 60, 120, 1440];
  if (options.contains(value)) return value;
  return 30;
}
