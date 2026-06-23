part of 'equipamentos_page.dart';

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left_rounded,
                  color: Color(0xFF1696AA), size: 28),
              Text('Voltar', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        _LegendItem(color: Color(0xFF36C76B), label: 'Em uso'),
        _LegendItem(color: Color(0xFFFFC400), label: 'Revisao proxima'),
        _LegendItem(color: Color(0xFFFF4040), label: 'Manutencao atrasada'),
        _LegendItem(color: Color(0xFF9EA1A6), label: 'Fora de uso'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 10)),
      ],
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({required this.equipamento});

  final Equipamento equipamento;

  @override
  Widget build(BuildContext context) {
    final status = equipamento.statusInfo;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _EquipmentPicture(equipamento: equipamento, size: 88),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipamento.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF222222),
                  ),
                ),
                Text('Marca: ${emptyDash(equipamento.marca)}',
                    style: _detailStyle()),
                Text('Modelo: ${emptyDash(equipamento.modelo)}',
                    style: _detailStyle()),
                Text(
                  'Local onde e guardado: ${emptyDash(equipamento.localGuardado)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _detailStyle(),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, color: status.color, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFA9D9E1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1696AA), size: 24),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _mutedStyle()),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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

class _MaintenanceEntry extends StatelessWidget {
  const _MaintenanceEntry({required this.manutencao});

  final ManutencaoEquipamento manutencao;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 9, 10, 9),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFA9D9E1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.build_rounded,
              color: Color(0xFF1696AA),
              size: 23,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatDate(manutencao.dataManutencao)} - ${manutencao.tipoManutencao}',
                  style: const TextStyle(
                    color: Color(0xFF1696AA),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (manutencao.descricaoServico.isNotEmpty)
                  _MiniLine(
                    icon: Icons.cleaning_services_rounded,
                    text: manutencao.descricaoServico,
                  ),
                if (manutencao.pecasTrocadas.isNotEmpty)
                  _MiniLine(
                    icon: Icons.construction_rounded,
                    text: manutencao.pecasTrocadas,
                  ),
                if (manutencao.problemaRelatado.isNotEmpty)
                  _MiniLine(
                    icon: Icons.warning_amber_rounded,
                    text: manutencao.problemaRelatado,
                  ),
                if (manutencao.profissionalEmpresa.isNotEmpty)
                  _MiniLine(
                    icon: Icons.person_outline_rounded,
                    text: manutencao.profissionalEmpresa,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1696AA), size: 15),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentPicture extends StatelessWidget {
  const _EquipmentPicture({required this.equipamento, required this.size});

  final Equipamento equipamento;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: equipamento.urlFoto.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                equipamento.urlFoto,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _EquipmentIcon(
                  nome: equipamento.nome,
                  size: size,
                ),
              ),
            )
          : _EquipmentIcon(nome: equipamento.nome, size: size),
    );
  }
}

class _EquipmentIcon extends StatelessWidget {
  const _EquipmentIcon({required this.nome, required this.size});

  final String nome;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = nome.toLowerCase();
    final icon = normalized.contains('cadeira')
        ? Icons.accessible_rounded
        : normalized.contains('ox')
            ? Icons.monitor_heart_outlined
            : normalized.contains('glic')
                ? Icons.bloodtype_outlined
                : Icons.medical_services_outlined;
    return Icon(icon, color: const Color(0xFF073248), size: size * 0.55);
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
          SizedBox(
            height: maxLines == 1 ? 40 : null,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 15),
              decoration: _inputDecoration(suffix: suffix),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
          SizedBox(
            height: 40,
            child: TextField(
              controller: controller,
              readOnly: true,
              onTap: onTap,
              style: const TextStyle(fontSize: 15),
              decoration: _inputDecoration(
                suffix: const Icon(Icons.calendar_month_rounded, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE1F3F6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF38AFC0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              color: const Color(0xFF1696AA),
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF073248),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF38AFC0), size: 50),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF073248),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({Widget? suffix}) {
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
    suffixIcon: suffix,
    suffixIconColor: const Color(0xFF1696AA),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF38AFC0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF1696AA), width: 1.4),
    ),
  );
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF3CA7B8),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 7,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

TextStyle _mutedStyle() {
  return const TextStyle(color: Color(0xFF8C8C8C), fontSize: 12, height: 1.22);
}

TextStyle _detailStyle() {
  return const TextStyle(color: Color(0xFF222222), fontSize: 12.5, height: 1.2);
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.length >= 10 ? text.substring(0, 10) : text);
}

String formatDate(DateTime? date) {
  if (date == null) return '--/--/----';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String isoDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String emptyDash(String value) => value.trim().isEmpty ? '-' : value;

DateTime? nextMaintenanceDate(DateTime date, int? frequencyDays) {
  if (frequencyDays == null || frequencyDays <= 0) return null;
  return date.add(Duration(days: frequencyDays));
}

String normalizeStatus(String? status) {
  final normalized = status?.trim().toLowerCase().replaceAll('_', ' ') ?? '';
  if (normalized.contains('fora')) return 'Fora de uso';
  if (normalized.contains('atras')) return 'Manutencao atrasada';
  if (normalized.contains('revis') || normalized.contains('proxima')) {
    return 'Revisao proxima';
  }
  return 'Em uso';
}

EquipamentoStatus statusInfoFor(Equipamento equipamento) {
  if (equipamento.status == 'Fora de uso') {
    return const EquipamentoStatus(
      label: 'Fora de uso',
      color: Color(0xFF9EA1A6),
      icon: Icons.cloud_off_rounded,
    );
  }

  final next = equipamento.proximaManutencaoEm;
  final now = DateTime.now();
  if (next != null) {
    final today = DateTime(now.year, now.month, now.day);
    final nextDay = DateTime(next.year, next.month, next.day);
    final days = nextDay.difference(today).inDays;
    if (days < 0 || equipamento.status == 'Manutencao atrasada') {
      return const EquipamentoStatus(
        label: 'Manutencao atrasada',
        color: Color(0xFFFF4040),
        icon: Icons.warning_amber_rounded,
      );
    }
    if (days <= 15 || equipamento.status == 'Revisao proxima') {
      return EquipamentoStatus(
        label: 'Manutencao em $days dias',
        color: const Color(0xFFFFC400),
        icon: Icons.schedule_rounded,
      );
    }
  }

  return const EquipamentoStatus(
    label: 'Em uso',
    color: Color(0xFF36C76B),
    icon: Icons.check_circle_rounded,
  );
}
