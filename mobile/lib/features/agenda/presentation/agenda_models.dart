class AgendaCompromisso {
  const AgendaCompromisso({
    required this.id,
    required this.titulo,
    required this.tag,
    required this.dataHora,
    required this.local,
    required this.frequencia,
    required this.observacoes,
    required this.ativarLembrete,
    required this.antecedenciaLembreteMinutos,
    required this.status,
    this.ocorrenciasStatus = const {},
    this.dataOcorrencia,
    this.criadoPorNome,
    this.criadoPorId,
  });

  factory AgendaCompromisso.fromJson(Map<String, dynamic> json) {
    final inicio = json['inicio_em'] ?? json['inicioEm'];
    final dataCompromisso = json['data_compromisso'] ?? json['dataCompromisso'];
    final horaCompromisso = json['hora_compromisso'] ?? json['horaCompromisso'];
    final lembrete = json['antecedencia_lembrete_minutos'] ??
        json['antecedenciaLembreteMinutos'] ??
        json['lembrete_minutos'] ??
        json['lembreteMinutos'];
    final tag =
        _parseTag(json['tags']) ?? json['tipo_evento'] ?? json['tipoEvento'];
    final frequencia = json['repeticao'] ?? json['frequencia'];
    final dataHora = _parseAgendaDateTime(
      inicio: inicio,
      dataCompromisso: dataCompromisso,
      horaCompromisso: horaCompromisso,
    );

    return AgendaCompromisso(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? 'Sem titulo',
      tag: tag?.toString() ?? 'Consulta',
      dataHora: dataHora,
      local: json['local']?.toString() ?? '',
      frequencia: _normalizeFrequencia(frequencia),
      observacoes: json['observacoes']?.toString() ?? '',
      ativarLembrete: json['ativar_lembrete'] == true ||
          json['ativarLembrete'] == true ||
          lembrete != null,
      antecedenciaLembreteMinutos:
          lembrete is num ? lembrete.toInt() : int.tryParse('$lembrete') ?? 30,
      status: json['status']?.toString() ?? 'agendado',
      ocorrenciasStatus: _parseOcorrenciasStatus(
        json['ocorrencias_status'] ?? json['ocorrenciasStatus'],
      ),
      criadoPorNome:
          (json['criado_por_nome'] ?? json['criadoPorNome'])?.toString().trim(),
      criadoPorId: (json['criado_por_id'] ?? json['criadoPorId'])?.toString(),
    );
  }

  final String id;
  final String titulo;
  final String tag;
  final DateTime dataHora;
  final String local;
  final String frequencia;
  final String observacoes;
  final bool ativarLembrete;
  final int antecedenciaLembreteMinutos;
  final String status;
  final Map<String, String> ocorrenciasStatus;
  final DateTime? dataOcorrencia;
  final String? criadoPorNome;
  final String? criadoPorId;

  AgendaCompromisso copyWith({
    String? id,
    String? titulo,
    String? tag,
    DateTime? dataHora,
    String? local,
    String? frequencia,
    String? observacoes,
    bool? ativarLembrete,
    int? antecedenciaLembreteMinutos,
    String? status,
    Map<String, String>? ocorrenciasStatus,
    DateTime? dataOcorrencia,
    String? criadoPorNome,
    String? criadoPorId,
  }) {
    return AgendaCompromisso(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      tag: tag ?? this.tag,
      dataHora: dataHora ?? this.dataHora,
      local: local ?? this.local,
      frequencia: frequencia ?? this.frequencia,
      observacoes: observacoes ?? this.observacoes,
      ativarLembrete: ativarLembrete ?? this.ativarLembrete,
      antecedenciaLembreteMinutos:
          antecedenciaLembreteMinutos ?? this.antecedenciaLembreteMinutos,
      status: status ?? this.status,
      ocorrenciasStatus: ocorrenciasStatus ?? this.ocorrenciasStatus,
      dataOcorrencia: dataOcorrencia ?? this.dataOcorrencia,
      criadoPorNome: criadoPorNome ?? this.criadoPorNome,
      criadoPorId: criadoPorId ?? this.criadoPorId,
    );
  }

  String statusNoDia(DateTime day) {
    final statusDaOcorrencia = ocorrenciasStatus[_formatPayloadDate(day)];
    if (statusDaOcorrencia != null) return statusDaOcorrencia;
    if (status == 'cancelado') return status;
    if (_isRecurringFrequency(frequencia)) return 'agendado';
    return status;
  }
}

class AgendaCompromissoFormData {
  const AgendaCompromissoFormData({
    required this.titulo,
    required this.tag,
    required this.dataHora,
    required this.local,
    required this.frequencia,
    required this.observacoes,
    required this.ativarLembrete,
    required this.antecedenciaLembreteMinutos,
    required this.status,
  });

  final String titulo;
  final String tag;
  final DateTime dataHora;
  final String local;
  final String frequencia;
  final String observacoes;
  final bool ativarLembrete;
  final int? antecedenciaLembreteMinutos;
  final String status;

  Map<String, dynamic> toPayload({
    required String idosoId,
    String? criadoPorId,
  }) {
    return {
      'titulo': titulo,
      'tags': [tag],
      'data_compromisso': _formatPayloadDate(dataHora),
      'hora_compromisso': _formatPayloadTime(dataHora),
      'local': local,
      'frequencia': frequencia,
      'observacoes': observacoes,
      'ativar_lembrete': ativarLembrete,
      if (ativarLembrete)
        'antecedencia_lembrete_minutos': antecedenciaLembreteMinutos ?? 30,
      'status': status,
      'idoso_id': idosoId,
      if (criadoPorId != null && criadoPorId.isNotEmpty)
        'criado_por_id': criadoPorId,
    };
  }
}

class AgendaFormResult {
  const AgendaFormResult({required this.data, required this.tags});

  final AgendaCompromissoFormData data;
  final List<String> tags;
}

DateTime _parseAgendaDateTime({
  required dynamic inicio,
  required dynamic dataCompromisso,
  required dynamic horaCompromisso,
}) {
  if (inicio != null) {
    final parsed = DateTime.tryParse(inicio.toString());
    if (parsed != null) return parsed.toLocal();
  }

  final date = _datePart(dataCompromisso);
  final time = _timePart(horaCompromisso);
  final composed = DateTime.tryParse('${date ?? ''}T${time ?? '00:00'}');
  return composed ?? DateTime.now();
}

String? _datePart(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.length >= 10) return text.substring(0, 10);
  return null;
}

String? _timePart(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.length >= 5) return text.substring(0, 5);
  return null;
}

String _formatPayloadDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatPayloadTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _normalizeFrequencia(dynamic value) {
  final text = value?.toString().trim();
  switch (text?.toLowerCase()) {
    case 'diario':
    case 'diariamente':
      return 'Diariamente';
    case 'semanal':
    case 'semanalmente':
      return 'Semanalmente';
    case 'mensal':
    case 'mensalmente':
      return 'Mensalmente';
    case 'anual':
    case 'anualmente':
      return 'Anualmente';
    case 'nao repetir':
    case 'n\u00e3o repetir':
      return 'Não repetir';
    default:
      return 'Semanalmente';
  }
}

String? _parseTag(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value.first?.toString();
  }

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('{') && text.endsWith('}')) {
      final content = text.substring(1, text.length - 1).trim();
      if (content.isEmpty) return null;
      return content.split(',').first.trim().replaceAll('"', '');
    }

    if (text.startsWith('[') && text.endsWith(']')) {
      final content = text.substring(1, text.length - 1).trim();
      if (content.isEmpty) return null;
      return content.split(',').first.trim().replaceAll('"', '');
    }

    return text;
  }

  return null;
}

Map<String, String> _parseOcorrenciasStatus(dynamic value) {
  if (value is! List) return const {};

  final result = <String, String>{};
  for (final item in value) {
    if (item is! Map) continue;
    final date = _datePart(item['data_ocorrencia'] ?? item['dataOcorrencia']);
    final status = item['status']?.toString();
    if (date != null && status != null && status.isNotEmpty) {
      result[date] = status;
    }
  }
  return result;
}

bool _isRecurringFrequency(String value) {
  final normalized = value.toLowerCase().trim();
  return normalized == 'diario' ||
      normalized == 'diariamente' ||
      normalized == 'semanal' ||
      normalized == 'semanalmente' ||
      normalized == 'mensal' ||
      normalized == 'mensalmente' ||
      normalized == 'anual' ||
      normalized == 'anualmente';
}
