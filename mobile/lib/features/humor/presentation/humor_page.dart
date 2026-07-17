import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/staggered_entry.dart';

class HumorPage extends ConsumerStatefulWidget {
  const HumorPage({super.key});

  @override
  ConsumerState<HumorPage> createState() => _HumorPageState();
}

class _HumorPageState extends ConsumerState<HumorPage> {
  final _observacoesController = TextEditingController();
  final _dataController = TextEditingController();
  final _horaController = TextEditingController();

  String _selectedMood = 'Feliz';
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataController.text = _formatBrazilianDate(now);
    _horaController.text = _formatTime(TimeOfDay.fromDateTime(now));
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    _dataController.dispose();
    _horaController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _parseBrazilianDate(_dataController.text) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );

    if (selected == null) return;
    setState(() => _dataController.text = _formatBrazilianDate(selected));
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _parseTime(_horaController.text) ?? TimeOfDay.now(),
    );

    if (selected == null) return;
    setState(() => _horaController.text = _formatTime(selected));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final idoso = ref.read(selectedIdosoProvider);
    final usuario = ref.read(authSessionProvider);

    if (idoso == null) {
      context.go('/idosos');
      return;
    }

    if (usuario == null || usuario.id.isEmpty) {
      setState(() => _errorMessage = 'Entre novamente para salvar o registro.');
      return;
    }

    final dataHumor = _toIsoDate(_dataController.text);
    final horarioRegi = _normalizeTime(_horaController.text);

    if (dataHumor == null || horarioRegi == null) {
      setState(() => _errorMessage = 'Informe uma data e um horario validos.');
      return;
    }

    final today = DateTime.now();
    final todayIso = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    if (dataHumor == todayIso) {
      final shouldContinue = await _confirmDuplicateToday(idoso.id, todayIso);
      if (!shouldContinue) return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(apiClientProvider).criarHumor(
            idosoId: idoso.id,
            humor: _selectedMood,
            dataHumor: dataHumor,
            horarioRegi: horarioRegi,
            registradoPorId: usuario.id,
            observacoes: _observacoesController.text,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Humor registrado com sucesso.')),
      );
      context.go('/monitoramento');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Nao foi possivel salvar o registro de humor.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDuplicateToday(String idosoId, String todayIso) async {
    try {
      final humores =
          await ref.read(apiClientProvider).listarHumores(idosoId: idosoId);
      final alreadyRegistered = humores.any((item) {
        final value = item['dataHumor'] ?? item['data_humor'];
        return value?.toString().startsWith(todayIso) == true;
      });

      if (!alreadyRegistered || !mounted) return true;

      return await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Humor ja cadastrado'),
                content: const Text(
                  'Voce ja cadastrou um humor hoje. Certeza que deseja adicionar outro?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Adicionar'),
                  ),
                ],
              );
            },
          ) ??
          false;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idoso = ref.watch(selectedIdosoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      onBack: () => context.go('/monitoramento'),
                      onProfile: () => context.go('/perfil?from=humor'),
                    ),
                    const SizedBox(height: 10),
                    StaggeredEntry(index: 0, child: _IdosoCard(idoso: idoso)),
                    const SizedBox(height: 19),
                    StaggeredEntry(
                      index: 1,
                      child: Text(
                        'Como ${_firstName(idoso?.nome ?? 'o idoso')} esta hoje?',
                        style: const TextStyle(
                          color: Color(0xFF242424),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredEntry(
                      index: 2,
                      child: _MoodSelector(
                        selectedMood: _selectedMood,
                        onChanged: (value) {
                          setState(() {
                            _selectedMood = value;
                            _errorMessage = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    StaggeredEntry(
                      index: 3,
                      child: _ObservationBox(
                        controller: _observacoesController,
                      ),
                    ),
                    const SizedBox(height: 23),
                    StaggeredEntry(
                      index: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: _SmallField(
                              label: 'Data',
                              controller: _dataController,
                              icon: Icons.calendar_month_rounded,
                              onTap: _selectDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SmallField(
                              label: 'Hora',
                              controller: _horaController,
                              icon: Icons.access_time_rounded,
                              onTap: _selectTime,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
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
                    const SizedBox(height: 32),
                    StaggeredEntry(
                      index: 5,
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(
                            _saving ? 'Salvando...' : 'Salvar Registro',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF003B4F),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF7BA3AD),
                            elevation: 4,
                            shadowColor:
                                const Color(0xFF003B4F).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onProfile});

  final VoidCallback onBack;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF238FA1),
            size: 34,
          ),
        ),
        const Expanded(
          child: Text(
            'Registros de humor',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF238FA1),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ActionIconButton(
          tooltip: 'Perfil do cuidador',
          icon: Icons.person_rounded,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _IdosoCard extends StatelessWidget {
  const _IdosoCard({required this.idoso});

  final IdosoResumo? idoso;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(idoso?.urlFoto);

    return Container(
      height: 129,
      padding: const EdgeInsets.fromLTRB(13, 13, 17, 13),
      decoration: BoxDecoration(
        color: const Color(0xFF3CAAB6),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFFD1F2F6),
            backgroundImage: bytes != null
                ? MemoryImage(bytes)
                : idoso?.urlFoto != null && idoso!.urlFoto!.startsWith('http')
                    ? NetworkImage(idoso!.urlFoto!) as ImageProvider
                    : null,
            child: bytes == null &&
                    (idoso?.urlFoto == null ||
                        !idoso!.urlFoto!.startsWith('http'))
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF238FA1),
                    size: 58,
                  )
                : null,
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _firstName(idoso?.nome ?? 'Selecione'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Container(width: 94, height: 1.4, color: Colors.white),
                const SizedBox(height: 9),
                if (idoso != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.cake_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        idoso!.idade > 0
                            ? '${idoso!.idade} anos'
                            : 'Idade não informada',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  const _MoodSelector({
    required this.selectedMood,
    required this.onChanged,
  });

  final String selectedMood;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _moods.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            mainAxisExtent: 63,
          ),
          itemBuilder: (context, index) {
            final mood = _moods[index];
            return _MoodButton(
              mood: mood,
              selected: selectedMood == mood.label,
              onTap: () => onChanged(mood.label),
            );
          },
        ),
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final _Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2FAD9F) : const Color(0xFF2A9CAF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0F4F1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF2FAD9F) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: selected ? 1 : 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 1 + value * 0.18,
                  child: child,
                );
              },
              child: Icon(mood.icon, color: color, size: 38),
            ),
            const SizedBox(height: 3),
            Text(
              mood.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF19796F)
                    : const Color(0xFF666666),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationBox extends StatelessWidget {
  const _ObservationBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF2A9CAF),
                size: 19,
              ),
              SizedBox(width: 6),
              Text(
                'Observações',
                style: TextStyle(
                  color: Color(0xFF17324D),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF2FBFC),
              hintText: 'Conte como foi o dia.',
              hintStyle: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFCDE7EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFCDE7EA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color(0xFF2FAD9F),
                  width: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCF1F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF148A9C), size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF6F636B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      controller.text,
                      style: const TextStyle(
                        color: Color(0xFF17324D),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mood {
  const _Mood(this.label, this.icon);

  final String label;
  final IconData icon;
}

const _moods = [
  _Mood('Feliz', Icons.sentiment_satisfied_alt_rounded),
  _Mood('Calma', Icons.spa_rounded),
  _Mood('Triste', Icons.sentiment_dissatisfied_rounded),
  _Mood('Chorona', Icons.sentiment_very_dissatisfied_rounded),
  _Mood('Irritada', Icons.mood_bad_rounded),
  _Mood('Sonolenta', Icons.nights_stay_rounded),
];

String _firstName(String nome) {
  final trimmed = nome.trim();
  if (trimmed.isEmpty) return 'Idoso';
  return trimmed.split(RegExp(r'\s+')).first;
}

Uint8List? _dataImageBytes(String? value) {
  if (value == null || !value.startsWith('data:image')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

String _formatBrazilianDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

DateTime? _parseBrazilianDate(String value) {
  final pieces = value.split('/');
  if (pieces.length != 3) return null;
  final day = int.tryParse(pieces[0]);
  final month = int.tryParse(pieces[1]);
  final year = int.tryParse(pieces[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String? _toIsoDate(String value) {
  final date = _parseBrazilianDate(value);
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

TimeOfDay? _parseTime(String value) {
  final pieces = value.split(':');
  if (pieces.length != 2) return null;
  final hour = int.tryParse(pieces[0]);
  final minute = int.tryParse(pieces[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String? _normalizeTime(String value) {
  final time = _parseTime(value);
  if (time == null) return null;
  return _formatTime(time);
}
