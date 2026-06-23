part of 'equipamentos_page.dart';

class Equipamento {
  const Equipamento({
    required this.id,
    required this.nome,
    required this.marca,
    required this.modelo,
    required this.dataAquisicao,
    required this.validade,
    required this.ultimaManutencaoEm,
    required this.frequenciaManutencaoDias,
    required this.proximaManutencaoEm,
    required this.localGuardado,
    required this.urlManual,
    required this.urlFoto,
    required this.observacoesSeguranca,
    required this.status,
  });

  factory Equipamento.fromJson(Map<String, dynamic> json) {
    final frequencia =
        json['frequencia_manutencao_dias'] ?? json['frequenciaManutencaoDias'];
    return Equipamento(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? 'Equipamento',
      marca: json['marca']?.toString() ?? '',
      modelo: json['modelo']?.toString() ?? '',
      dataAquisicao: parseDate(json['data_aquisicao'] ?? json['dataAquisicao']),
      validade: parseDate(json['validade']),
      ultimaManutencaoEm: parseDate(
        json['ultima_manutencao_em'] ?? json['ultimaManutencaoEm'],
      ),
      frequenciaManutencaoDias:
          frequencia is num ? frequencia.toInt() : int.tryParse('$frequencia'),
      proximaManutencaoEm: parseDate(
        json['proxima_manutencao_em'] ?? json['proximaManutencaoEm'],
      ),
      localGuardado: json['local_guardado']?.toString() ??
          json['localGuardado']?.toString() ??
          '',
      urlManual:
          json['url_manual']?.toString() ?? json['urlManual']?.toString() ?? '',
      urlFoto:
          json['url_foto']?.toString() ?? json['urlFoto']?.toString() ?? '',
      observacoesSeguranca: json['observacoes_seguranca']?.toString() ??
          json['observacoesSeguranca']?.toString() ??
          '',
      status: normalizeStatus(json['status']?.toString()),
    );
  }

  final String id;
  final String nome;
  final String marca;
  final String modelo;
  final DateTime? dataAquisicao;
  final DateTime? validade;
  final DateTime? ultimaManutencaoEm;
  final int? frequenciaManutencaoDias;
  final DateTime? proximaManutencaoEm;
  final String localGuardado;
  final String urlManual;
  final String urlFoto;
  final String observacoesSeguranca;
  final String status;

  EquipamentoStatus get statusInfo => statusInfoFor(this);

  Equipamento copyWith({
    DateTime? ultimaManutencaoEm,
    DateTime? proximaManutencaoEm,
    String? status,
  }) {
    return Equipamento(
      id: id,
      nome: nome,
      marca: marca,
      modelo: modelo,
      dataAquisicao: dataAquisicao,
      validade: validade,
      ultimaManutencaoEm: ultimaManutencaoEm ?? this.ultimaManutencaoEm,
      frequenciaManutencaoDias: frequenciaManutencaoDias,
      proximaManutencaoEm: proximaManutencaoEm ?? this.proximaManutencaoEm,
      localGuardado: localGuardado,
      urlManual: urlManual,
      urlFoto: urlFoto,
      observacoesSeguranca: observacoesSeguranca,
      status: status ?? this.status,
    );
  }
}

class EquipamentoFormData {
  const EquipamentoFormData({
    required this.nome,
    required this.marca,
    required this.modelo,
    required this.dataAquisicao,
    required this.validade,
    required this.ultimaManutencaoEm,
    required this.frequenciaManutencaoDias,
    required this.localGuardado,
    required this.urlManual,
    required this.observacoesSeguranca,
  });

  final String nome;
  final String marca;
  final String modelo;
  final DateTime? dataAquisicao;
  final DateTime? validade;
  final DateTime? ultimaManutencaoEm;
  final int? frequenciaManutencaoDias;
  final String localGuardado;
  final String urlManual;
  final String observacoesSeguranca;

  Map<String, dynamic> toPayload({
    required String idosoId,
    String? criadoPorId,
  }) {
    return {
      'idosoId': idosoId,
      if (criadoPorId != null && criadoPorId.isNotEmpty)
        'criadoPorId': criadoPorId,
      'nome': nome,
      if (marca.isNotEmpty) 'marca': marca,
      if (modelo.isNotEmpty) 'modelo': modelo,
      if (dataAquisicao != null) 'dataAquisicao': isoDate(dataAquisicao!),
      if (validade != null) 'validade': isoDate(validade!),
      if (ultimaManutencaoEm != null)
        'ultimaManutencaoEm': isoDate(ultimaManutencaoEm!),
      if (frequenciaManutencaoDias != null)
        'frequenciaManutencaoDias': frequenciaManutencaoDias,
      if (ultimaManutencaoEm != null && frequenciaManutencaoDias != null)
        'proximaManutencaoEm': isoDate(
          ultimaManutencaoEm!.add(Duration(days: frequenciaManutencaoDias!)),
        ),
      if (localGuardado.isNotEmpty) 'localGuardado': localGuardado,
      if (urlManual.isNotEmpty) 'urlManual': urlManual,
      if (observacoesSeguranca.isNotEmpty)
        'observacoesSeguranca': observacoesSeguranca,
      'status': 'Em uso',
    };
  }
}

class ManutencaoEquipamento {
  const ManutencaoEquipamento({
    required this.dataManutencao,
    required this.tipoManutencao,
    required this.descricaoServico,
    required this.problemaRelatado,
    required this.pecasTrocadas,
    required this.profissionalEmpresa,
  });

  factory ManutencaoEquipamento.fromJson(Map<String, dynamic> json) {
    return ManutencaoEquipamento(
      dataManutencao:
          parseDate(json['data_manutencao'] ?? json['dataManutencao']),
      tipoManutencao: json['tipo_manutencao']?.toString() ??
          json['tipoManutencao']?.toString() ??
          'Preventiva',
      descricaoServico: json['descricao_servico']?.toString() ??
          json['descricaoServico']?.toString() ??
          '',
      problemaRelatado: json['problema_relatado']?.toString() ??
          json['problemaRelatado']?.toString() ??
          '',
      pecasTrocadas: json['pecas_trocadas']?.toString() ??
          json['pecasTrocadas']?.toString() ??
          '',
      profissionalEmpresa: json['profissional_empresa']?.toString() ??
          json['profissionalEmpresa']?.toString() ??
          '',
    );
  }

  final DateTime? dataManutencao;
  final String tipoManutencao;
  final String descricaoServico;
  final String problemaRelatado;
  final String pecasTrocadas;
  final String profissionalEmpresa;
}

class ManutencaoFormData {
  const ManutencaoFormData({
    required this.dataManutencao,
    required this.tipoManutencao,
    required this.descricaoServico,
    required this.problemaRelatado,
    required this.pecasTrocadas,
    required this.profissionalEmpresa,
    required this.custo,
    required this.proximaManutencaoEm,
  });

  final DateTime dataManutencao;
  final String tipoManutencao;
  final String descricaoServico;
  final String problemaRelatado;
  final String pecasTrocadas;
  final String profissionalEmpresa;
  final double? custo;
  final DateTime? proximaManutencaoEm;

  Map<String, dynamic> toPayload({String? registradoPorId}) {
    return {
      'dataManutencao': isoDate(dataManutencao),
      'tipoManutencao': tipoManutencao,
      if (descricaoServico.isNotEmpty) 'descricaoServico': descricaoServico,
      if (problemaRelatado.isNotEmpty) 'problemaRelatado': problemaRelatado,
      if (pecasTrocadas.isNotEmpty) 'pecasTrocadas': pecasTrocadas,
      if (profissionalEmpresa.isNotEmpty)
        'profissionalEmpresa': profissionalEmpresa,
      if (custo != null) 'custo': custo,
      if (proximaManutencaoEm != null)
        'proximaManutencaoEm': isoDate(proximaManutencaoEm!),
      if (registradoPorId != null && registradoPorId.isNotEmpty)
        'registradoPorId': registradoPorId,
    };
  }
}

class EquipamentoStatus {
  const EquipamentoStatus({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}
