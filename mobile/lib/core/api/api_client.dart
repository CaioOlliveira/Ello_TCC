import 'package:dio/dio.dart';

import 'api_endpoints.dart';
import 'api_exception.dart';

class IdosoResumo {
  const IdosoResumo({
    required this.id,
    required this.nome,
    required this.idade,
    required this.condicoes,
    this.urlFoto,
    this.pesoKg,
    this.tipoSanguineo,
    this.dataNascimento,
    this.sexo,
    this.limitacoes,
    this.observacoesGerais,
    this.alergiasRestricoes,
    this.contatoEmergenciaNome,
    this.contatoEmergenciaTelefone,
    this.contatoEmergenciaParentesco,
    this.monitoramentos = const [],
  });

  factory IdosoResumo.fromJson(Map<String, dynamic> json) {
    final condicoes = json['condicoes'];
    final monitoramentos = json['monitoramentos'];

    return IdosoResumo(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? 'Sem nome',
      idade: json['idade'] is num ? (json['idade'] as num).toInt() : 0,
      urlFoto: json['urlFoto']?.toString() ?? json['url_foto']?.toString(),
      pesoKg: _numOrNull(json['pesoKg'] ?? json['peso_kg']),
      tipoSanguineo: json['tipoSanguineo']?.toString() ??
          json['tipo_sanguineo']?.toString(),
      dataNascimento: json['dataNascimento']?.toString() ??
          json['data_nascimento']?.toString(),
      sexo: json['sexo']?.toString(),
      limitacoes: json['limitacoes']?.toString(),
      observacoesGerais: json['observacoesGerais']?.toString() ??
          json['observacoes_saude']?.toString(),
      alergiasRestricoes: json['alergiasRestricoes']?.toString() ??
          json['alergias_restricoes']?.toString(),
      contatoEmergenciaNome: json['contatoEmergenciaNome']?.toString() ??
          json['contato_emergencia_nome']?.toString(),
      contatoEmergenciaTelefone:
          json['contatoEmergenciaTelefone']?.toString() ??
              json['contato_emergencia_telefone']?.toString(),
      contatoEmergenciaParentesco:
          json['contatoEmergenciaParentesco']?.toString() ??
              json['contato_emergencia_parentesco']?.toString(),
      condicoes: condicoes is List
          ? condicoes.map((item) => item.toString()).toList()
          : const [],
      monitoramentos: monitoramentos is List
          ? monitoramentos.map((item) => item.toString()).toList()
          : const [],
    );
  }

  final String id;
  final String nome;
  final int idade;
  final String? urlFoto;
  final double? pesoKg;
  final String? tipoSanguineo;
  final String? dataNascimento;
  final String? sexo;
  final String? limitacoes;
  final String? observacoesGerais;
  final String? alergiasRestricoes;
  final String? contatoEmergenciaNome;
  final String? contatoEmergenciaTelefone;
  final String? contatoEmergenciaParentesco;
  final List<String> condicoes;
  final List<String> monitoramentos;

  IdosoResumo copyWith({
    String? nome,
    int? idade,
    String? urlFoto,
    double? pesoKg,
    String? tipoSanguineo,
    String? dataNascimento,
    String? sexo,
    String? limitacoes,
    String? observacoesGerais,
    String? alergiasRestricoes,
    String? contatoEmergenciaNome,
    String? contatoEmergenciaTelefone,
    String? contatoEmergenciaParentesco,
    List<String>? condicoes,
    List<String>? monitoramentos,
  }) {
    return IdosoResumo(
      id: id,
      nome: nome ?? this.nome,
      idade: idade ?? this.idade,
      urlFoto: urlFoto ?? this.urlFoto,
      pesoKg: pesoKg ?? this.pesoKg,
      tipoSanguineo: tipoSanguineo ?? this.tipoSanguineo,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      sexo: sexo ?? this.sexo,
      limitacoes: limitacoes ?? this.limitacoes,
      observacoesGerais: observacoesGerais ?? this.observacoesGerais,
      alergiasRestricoes: alergiasRestricoes ?? this.alergiasRestricoes,
      contatoEmergenciaNome:
          contatoEmergenciaNome ?? this.contatoEmergenciaNome,
      contatoEmergenciaTelefone:
          contatoEmergenciaTelefone ?? this.contatoEmergenciaTelefone,
      contatoEmergenciaParentesco:
          contatoEmergenciaParentesco ?? this.contatoEmergenciaParentesco,
      condicoes: condicoes ?? this.condicoes,
      monitoramentos: monitoramentos ?? this.monitoramentos,
    );
  }
}

class AiConversa {
  const AiConversa({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.criadoEm,
    required this.atualizadoEm,
    this.idosoId,
  });

  factory AiConversa.fromJson(Map<String, dynamic> json) {
    return AiConversa(
      id: json['id']?.toString() ?? '',
      usuarioId:
          json['usuarioId']?.toString() ?? json['usuario_id']?.toString() ?? '',
      idosoId: json['idosoId']?.toString() ?? json['idoso_id']?.toString(),
      titulo: json['titulo']?.toString() ?? 'Novo chat',
      criadoEm: DateTime.tryParse(
            json['criadoEm']?.toString() ?? json['criado_em']?.toString() ?? '',
          ) ??
          DateTime.now(),
      atualizadoEm: DateTime.tryParse(
            json['atualizadoEm']?.toString() ??
                json['atualizado_em']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }

  final String id;
  final String usuarioId;
  final String? idosoId;
  final String titulo;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
}

class AiMensagem {
  const AiMensagem({
    required this.id,
    required this.conversaId,
    required this.remetente,
    required this.conteudo,
    required this.criadoEm,
  });

  factory AiMensagem.fromJson(Map<String, dynamic> json) {
    return AiMensagem(
      id: json['id']?.toString() ?? '',
      conversaId: json['conversaId']?.toString() ??
          json['conversa_id']?.toString() ??
          '',
      remetente: json['remetente']?.toString() ?? 'ia',
      conteudo: json['conteudo']?.toString() ?? '',
      criadoEm: DateTime.tryParse(
            json['criadoEm']?.toString() ?? json['criado_em']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  final String id;
  final String conversaId;
  final String remetente;
  final String conteudo;
  final DateTime criadoEm;

  bool get fromUser => remetente == 'usuario';
}

class AiPerguntaResposta {
  const AiPerguntaResposta({
    required this.resposta,
    this.conversa,
    this.mensagem,
  });

  factory AiPerguntaResposta.fromJson(Map<String, dynamic> json) {
    final conversa = json['conversa'];
    final mensagem = json['mensagem'];

    return AiPerguntaResposta(
      resposta: json['resposta']?.toString() ?? '',
      conversa: conversa is Map<String, dynamic>
          ? AiConversa.fromJson(conversa)
          : null,
      mensagem: mensagem is Map<String, dynamic>
          ? AiMensagem.fromJson(mensagem)
          : null,
    );
  }

  final String resposta;
  final AiConversa? conversa;
  final AiMensagem? mensagem;
}

class AiRelatorioSecao {
  const AiRelatorioSecao({
    required this.tipo,
    required this.titulo,
    required this.texto,
  });

  factory AiRelatorioSecao.fromJson(Map<String, dynamic> json) {
    return AiRelatorioSecao(
      tipo: json['tipo']?.toString() ?? 'dica',
      titulo: json['titulo']?.toString() ?? 'Resumo',
      texto: json['texto']?.toString() ?? '',
    );
  }

  final String tipo;
  final String titulo;
  final String texto;
}

class AiRelatorioInicial {
  const AiRelatorioInicial({
    required this.mensagemInicial,
    required this.secoes,
  });

  factory AiRelatorioInicial.fromJson(Map<String, dynamic> json) {
    final secoes = json['secoes'];

    return AiRelatorioInicial(
      mensagemInicial: json['mensagemInicial']?.toString() ??
          'Analisei os dados recentes e preparei um resumo geral.',
      secoes: secoes is List
          ? secoes
              .whereType<Map<String, dynamic>>()
              .map(AiRelatorioSecao.fromJson)
              .toList()
          : const [],
    );
  }

  final String mensagemInicial;
  final List<AiRelatorioSecao> secoes;
}

class GlicemiaRegistro {
  const GlicemiaRegistro({
    required this.id,
    required this.idosoId,
    required this.valor,
    required this.contexto,
    required this.medidoEm,
    this.observacoes,
    this.sintomas,
  });

  factory GlicemiaRegistro.fromJson(Map<String, dynamic> json) {
    return GlicemiaRegistro(
      id: json['id']?.toString() ?? '',
      idosoId: json['idosoId']?.toString() ?? '',
      valor: json['valor'] is num ? (json['valor'] as num).toInt() : 0,
      contexto: json['contexto']?.toString() ?? '',
      medidoEm: (DateTime.tryParse(json['medidoEm']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      observacoes: json['observacoes']?.toString(),
      sintomas: json['sintomas']?.toString(),
    );
  }

  final String id;
  final String idosoId;
  final int valor;
  final String contexto;
  final DateTime medidoEm;
  final String? observacoes;
  final String? sintomas;
}

class InsulinaRegistro {
  const InsulinaRegistro({
    required this.id,
    required this.idosoId,
    required this.tipoInsulina,
    required this.doseUnidades,
    required this.aplicadoEm,
    this.glicemiaId,
    this.nomeInsulina,
    this.localAplicacao,
    this.observacoes,
  });

  factory InsulinaRegistro.fromJson(Map<String, dynamic> json) {
    return InsulinaRegistro(
      id: json['id']?.toString() ?? '',
      idosoId: json['idosoId']?.toString() ?? '',
      glicemiaId: json['glicemiaId']?.toString(),
      nomeInsulina: json['nomeInsulina']?.toString(),
      tipoInsulina: json['tipoInsulina']?.toString() ?? '',
      doseUnidades: json['doseUnidades'] is num
          ? (json['doseUnidades'] as num).toDouble()
          : double.tryParse(json['doseUnidades']?.toString() ?? '') ?? 0,
      aplicadoEm: (DateTime.tryParse(json['aplicadoEm']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      localAplicacao: json['localAplicacao']?.toString(),
      observacoes: json['observacoes']?.toString(),
    );
  }

  final String id;
  final String idosoId;
  final String? glicemiaId;
  final String? nomeInsulina;
  final String tipoInsulina;
  final double doseUnidades;
  final DateTime aplicadoEm;
  final String? localAplicacao;
  final String? observacoes;
}

class GlicemiaHistoricoBadge {
  const GlicemiaHistoricoBadge({required this.texto, required this.cor});

  factory GlicemiaHistoricoBadge.fromJson(Map<String, dynamic>? json) {
    return GlicemiaHistoricoBadge(
      texto: json?['texto']?.toString() ?? '',
      cor: json?['cor']?.toString() ?? 'neutro',
    );
  }

  final String texto;
  final String cor;
}

class GlicemiaHistoricoEntrada {
  const GlicemiaHistoricoEntrada({
    required this.id,
    required this.usuarioNome,
    required this.acao,
    required this.descricao,
    required this.dataHora,
    required this.badge,
    this.valor,
  });

  factory GlicemiaHistoricoEntrada.fromJson(Map<String, dynamic> json) {
    final valor = json['valor'];

    return GlicemiaHistoricoEntrada(
      id: json['id']?.toString() ?? '',
      usuarioNome: json['usuarioNome']?.toString() ?? 'Cuidador',
      acao: json['acao']?.toString() ?? 'criar',
      descricao: json['descricao']?.toString() ?? '',
      valor: valor is num ? valor.toInt() : null,
      dataHora: (DateTime.tryParse(json['dataHora']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      badge: GlicemiaHistoricoBadge.fromJson(
        json['badge'] is Map<String, dynamic> ? json['badge'] : null,
      ),
    );
  }

  final String id;
  final String usuarioNome;
  final String acao;
  final String descricao;
  final int? valor;
  final DateTime dataHora;
  final GlicemiaHistoricoBadge badge;
}

class GlicemiaSeriePonto {
  const GlicemiaSeriePonto({
    required this.data,
    required this.rotulo,
    this.valor,
  });

  factory GlicemiaSeriePonto.fromJson(Map<String, dynamic> json) {
    final valor = json['valor'];

    return GlicemiaSeriePonto(
      data: json['data']?.toString() ?? '',
      rotulo: json['rotulo']?.toString() ?? '',
      valor: valor is num ? valor.toDouble() : null,
    );
  }

  final String data;
  final String rotulo;
  final double? valor;
}

class GlicemiaAlerta {
  const GlicemiaAlerta({
    required this.status,
    required this.titulo,
    required this.mensagem,
    required this.cor,
  });

  factory GlicemiaAlerta.fromJson(Map<String, dynamic>? json) {
    return GlicemiaAlerta(
      status: json?['status']?.toString() ?? 'sem_registro',
      titulo: json?['titulo']?.toString() ?? 'Sem medicao registrada',
      mensagem: json?['mensagem']?.toString() ??
          'Registre a primeira glicemia para gerar alertas.',
      cor: json?['cor']?.toString() ?? 'neutro',
    );
  }

  final String status;
  final String titulo;
  final String mensagem;
  final String cor;
}

class GlicemiaAnalise {
  const GlicemiaAnalise({
    required this.totalMedicoes,
    required this.totalForaDaFaixa,
    required this.texto,
    this.mediaUltimos7Dias,
  });

  factory GlicemiaAnalise.fromJson(Map<String, dynamic>? json) {
    final media = json?['mediaUltimos7Dias'];

    return GlicemiaAnalise(
      mediaUltimos7Dias: media is num ? media.toDouble() : null,
      totalMedicoes: json?['totalMedicoes'] is num
          ? (json?['totalMedicoes'] as num).toInt()
          : 0,
      totalForaDaFaixa: json?['totalForaDaFaixa'] is num
          ? (json?['totalForaDaFaixa'] as num).toInt()
          : 0,
      texto: json?['texto']?.toString() ??
          'Ainda nao ha medicoes suficientes para gerar uma analise.',
    );
  }

  final double? mediaUltimos7Dias;
  final int totalMedicoes;
  final int totalForaDaFaixa;
  final String texto;
}

class GlicemiaResumo {
  const GlicemiaResumo({
    required this.totalRegistros,
    required this.totalInsulinas,
    required this.alerta,
    required this.analise,
    required this.serie,
    this.ultima,
    this.mediaDia,
    this.proximaMedicao,
    this.insulinaRecente,
  });

  factory GlicemiaResumo.fromJson(Map<String, dynamic> json) {
    final ultima = json['ultima'];
    final serie = json['serie'];
    final insulinaRecente = json['insulinaRecente'];
    final proximaMedicao = json['proximaMedicao']?.toString();
    final mediaDia = json['mediaDia'];

    return GlicemiaResumo(
      ultima: ultima is Map<String, dynamic>
          ? GlicemiaRegistro.fromJson(ultima)
          : null,
      totalRegistros: json['totalRegistros'] is num
          ? (json['totalRegistros'] as num).toInt()
          : 0,
      mediaDia: mediaDia is num ? mediaDia.toDouble() : null,
      proximaMedicao: proximaMedicao == null
          ? null
          : DateTime.tryParse(proximaMedicao)?.toLocal(),
      alerta: GlicemiaAlerta.fromJson(
        json['alerta'] is Map<String, dynamic> ? json['alerta'] : null,
      ),
      analise: GlicemiaAnalise.fromJson(
        json['analise'] is Map<String, dynamic> ? json['analise'] : null,
      ),
      serie: serie is List
          ? serie
              .whereType<Map<String, dynamic>>()
              .map(GlicemiaSeriePonto.fromJson)
              .toList()
          : const [],
      insulinaRecente: insulinaRecente is Map<String, dynamic>
          ? InsulinaRegistro.fromJson(insulinaRecente)
          : null,
      totalInsulinas: json['totalInsulinas'] is num
          ? (json['totalInsulinas'] as num).toInt()
          : 0,
    );
  }

  final GlicemiaRegistro? ultima;
  final int totalRegistros;
  final double? mediaDia;
  final DateTime? proximaMedicao;
  final GlicemiaAlerta alerta;
  final GlicemiaAnalise analise;
  final List<GlicemiaSeriePonto> serie;
  final InsulinaRegistro? insulinaRecente;
  final int totalInsulinas;
}

class PressaoRegistro {
  const PressaoRegistro({
    required this.id,
    required this.idosoId,
    required this.sistolica,
    required this.diastolica,
    required this.medidoEm,
    this.batimentos,
    this.observacoes,
  });

  factory PressaoRegistro.fromJson(Map<String, dynamic> json) {
    final batimentos = json['batimentos'];

    return PressaoRegistro(
      id: json['id']?.toString() ?? '',
      idosoId: json['idosoId']?.toString() ?? '',
      sistolica:
          json['sistolica'] is num ? (json['sistolica'] as num).toInt() : 0,
      diastolica:
          json['diastolica'] is num ? (json['diastolica'] as num).toInt() : 0,
      batimentos: batimentos is num ? batimentos.toInt() : null,
      medidoEm: (DateTime.tryParse(json['medidoEm']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      observacoes: json['observacoes']?.toString(),
    );
  }

  final String id;
  final String idosoId;
  final int sistolica;
  final int diastolica;
  final int? batimentos;
  final DateTime medidoEm;
  final String? observacoes;
}

class PressaoHistoricoEntrada {
  const PressaoHistoricoEntrada({
    required this.id,
    required this.usuarioNome,
    required this.acao,
    required this.descricao,
    required this.dataHora,
    required this.badge,
    this.sistolica,
    this.diastolica,
  });

  factory PressaoHistoricoEntrada.fromJson(Map<String, dynamic> json) {
    final sistolica = json['sistolica'];
    final diastolica = json['diastolica'];

    return PressaoHistoricoEntrada(
      id: json['id']?.toString() ?? '',
      usuarioNome: json['usuarioNome']?.toString() ?? 'Cuidador',
      acao: json['acao']?.toString() ?? 'criar',
      descricao: json['descricao']?.toString() ?? '',
      sistolica: sistolica is num ? sistolica.toInt() : null,
      diastolica: diastolica is num ? diastolica.toInt() : null,
      dataHora: (DateTime.tryParse(json['dataHora']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      badge: GlicemiaHistoricoBadge.fromJson(
        json['badge'] is Map<String, dynamic> ? json['badge'] : null,
      ),
    );
  }

  final String id;
  final String usuarioNome;
  final String acao;
  final String descricao;
  final int? sistolica;
  final int? diastolica;
  final DateTime dataHora;
  final GlicemiaHistoricoBadge badge;
}

class PressaoSeriePonto {
  const PressaoSeriePonto({
    required this.data,
    required this.rotulo,
    this.valor,
  });

  factory PressaoSeriePonto.fromJson(Map<String, dynamic> json) {
    final valor = json['valor'];

    return PressaoSeriePonto(
      data: json['data']?.toString() ?? '',
      rotulo: json['rotulo']?.toString() ?? '',
      valor: valor is num ? valor.toDouble() : null,
    );
  }

  final String data;
  final String rotulo;
  final double? valor;
}

class PressaoAlerta {
  const PressaoAlerta({
    required this.status,
    required this.titulo,
    required this.mensagem,
    required this.cor,
  });

  factory PressaoAlerta.fromJson(Map<String, dynamic>? json) {
    return PressaoAlerta(
      status: json?['status']?.toString() ?? 'sem_registro',
      titulo: json?['titulo']?.toString() ?? 'Sem medicao registrada',
      mensagem: json?['mensagem']?.toString() ??
          'Registre a primeira pressao para gerar alertas.',
      cor: json?['cor']?.toString() ?? 'neutro',
    );
  }

  final String status;
  final String titulo;
  final String mensagem;
  final String cor;
}

class PressaoAnalise {
  const PressaoAnalise({
    required this.totalMedicoes,
    required this.totalForaDaFaixa,
    required this.texto,
    this.mediaUltimos7Dias,
    this.mediaDiastolicaUltimos7Dias,
  });

  factory PressaoAnalise.fromJson(Map<String, dynamic>? json) {
    final media = json?['mediaUltimos7Dias'];
    final mediaDiastolica = json?['mediaDiastolicaUltimos7Dias'];

    return PressaoAnalise(
      mediaUltimos7Dias: media is num ? media.toDouble() : null,
      mediaDiastolicaUltimos7Dias:
          mediaDiastolica is num ? mediaDiastolica.toDouble() : null,
      totalMedicoes: json?['totalMedicoes'] is num
          ? (json?['totalMedicoes'] as num).toInt()
          : 0,
      totalForaDaFaixa: json?['totalForaDaFaixa'] is num
          ? (json?['totalForaDaFaixa'] as num).toInt()
          : 0,
      texto: json?['texto']?.toString() ??
          'Ainda nao ha medicoes suficientes para gerar uma analise.',
    );
  }

  final double? mediaUltimos7Dias;
  final double? mediaDiastolicaUltimos7Dias;
  final int totalMedicoes;
  final int totalForaDaFaixa;
  final String texto;
}

class PressaoResumo {
  const PressaoResumo({
    required this.totalRegistros,
    required this.alerta,
    required this.analise,
    required this.serie,
    this.ultima,
    this.mediaSistolicaDia,
    this.mediaDiastolicaDia,
    this.proximaMedicao,
  });

  factory PressaoResumo.fromJson(Map<String, dynamic> json) {
    final ultima = json['ultima'];
    final serie = json['serie'];
    final proximaMedicao = json['proximaMedicao']?.toString();
    final mediaSistolicaDia = json['mediaSistolicaDia'];
    final mediaDiastolicaDia = json['mediaDiastolicaDia'];

    return PressaoResumo(
      ultima: ultima is Map<String, dynamic>
          ? PressaoRegistro.fromJson(ultima)
          : null,
      totalRegistros: json['totalRegistros'] is num
          ? (json['totalRegistros'] as num).toInt()
          : 0,
      mediaSistolicaDia:
          mediaSistolicaDia is num ? mediaSistolicaDia.toDouble() : null,
      mediaDiastolicaDia:
          mediaDiastolicaDia is num ? mediaDiastolicaDia.toDouble() : null,
      proximaMedicao: proximaMedicao == null
          ? null
          : DateTime.tryParse(proximaMedicao)?.toLocal(),
      alerta: PressaoAlerta.fromJson(
        json['alerta'] is Map<String, dynamic> ? json['alerta'] : null,
      ),
      analise: PressaoAnalise.fromJson(
        json['analise'] is Map<String, dynamic> ? json['analise'] : null,
      ),
      serie: serie is List
          ? serie
              .whereType<Map<String, dynamic>>()
              .map(PressaoSeriePonto.fromJson)
              .toList()
          : const [],
    );
  }

  final PressaoRegistro? ultima;
  final int totalRegistros;
  final double? mediaSistolicaDia;
  final double? mediaDiastolicaDia;
  final DateTime? proximaMedicao;
  final PressaoAlerta alerta;
  final PressaoAnalise analise;
  final List<PressaoSeriePonto> serie;
}

class OxigenacaoRegistro {
  const OxigenacaoRegistro({
    required this.id,
    required this.idosoId,
    required this.saturacao,
    required this.medidoEm,
    this.pulso,
    this.observacoes,
  });

  factory OxigenacaoRegistro.fromJson(Map<String, dynamic> json) {
    final pulso = json['pulso'];

    return OxigenacaoRegistro(
      id: json['id']?.toString() ?? '',
      idosoId: json['idosoId']?.toString() ?? '',
      saturacao:
          json['saturacao'] is num ? (json['saturacao'] as num).toInt() : 0,
      pulso: pulso is num ? pulso.toInt() : null,
      medidoEm: (DateTime.tryParse(json['medidoEm']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      observacoes: json['observacoes']?.toString(),
    );
  }

  final String id;
  final String idosoId;
  final int saturacao;
  final int? pulso;
  final DateTime medidoEm;
  final String? observacoes;
}

class OxigenacaoHistoricoEntrada {
  const OxigenacaoHistoricoEntrada({
    required this.id,
    required this.usuarioNome,
    required this.acao,
    required this.descricao,
    required this.dataHora,
    required this.badge,
    this.saturacao,
    this.pulso,
  });

  factory OxigenacaoHistoricoEntrada.fromJson(Map<String, dynamic> json) {
    final saturacao = json['saturacao'];
    final pulso = json['pulso'];

    return OxigenacaoHistoricoEntrada(
      id: json['id']?.toString() ?? '',
      usuarioNome: json['usuarioNome']?.toString() ?? 'Cuidador',
      acao: json['acao']?.toString() ?? 'criar',
      descricao: json['descricao']?.toString() ?? '',
      saturacao: saturacao is num ? saturacao.toInt() : null,
      pulso: pulso is num ? pulso.toInt() : null,
      dataHora: (DateTime.tryParse(json['dataHora']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      badge: GlicemiaHistoricoBadge.fromJson(
        json['badge'] is Map<String, dynamic> ? json['badge'] : null,
      ),
    );
  }

  final String id;
  final String usuarioNome;
  final String acao;
  final String descricao;
  final int? saturacao;
  final int? pulso;
  final DateTime dataHora;
  final GlicemiaHistoricoBadge badge;
}

class OxigenacaoSeriePonto {
  const OxigenacaoSeriePonto({
    required this.data,
    required this.rotulo,
    this.valor,
  });

  factory OxigenacaoSeriePonto.fromJson(Map<String, dynamic> json) {
    final valor = json['valor'];

    return OxigenacaoSeriePonto(
      data: json['data']?.toString() ?? '',
      rotulo: json['rotulo']?.toString() ?? '',
      valor: valor is num ? valor.toDouble() : null,
    );
  }

  final String data;
  final String rotulo;
  final double? valor;
}

class OxigenacaoAlerta {
  const OxigenacaoAlerta({
    required this.status,
    required this.titulo,
    required this.mensagem,
    required this.cor,
  });

  factory OxigenacaoAlerta.fromJson(Map<String, dynamic>? json) {
    return OxigenacaoAlerta(
      status: json?['status']?.toString() ?? 'sem_registro',
      titulo: json?['titulo']?.toString() ?? 'Sem medicao registrada',
      mensagem: json?['mensagem']?.toString() ??
          'Registre a primeira oxigenação para gerar alertas.',
      cor: json?['cor']?.toString() ?? 'neutro',
    );
  }

  final String status;
  final String titulo;
  final String mensagem;
  final String cor;
}

class OxigenacaoAnalise {
  const OxigenacaoAnalise({
    required this.totalMedicoes,
    required this.totalForaDaFaixa,
    required this.texto,
    this.mediaUltimos7Dias,
    this.mediaPulsoUltimos7Dias,
  });

  factory OxigenacaoAnalise.fromJson(Map<String, dynamic>? json) {
    final media = json?['mediaUltimos7Dias'];
    final mediaPulso = json?['mediaPulsoUltimos7Dias'];

    return OxigenacaoAnalise(
      mediaUltimos7Dias: media is num ? media.toDouble() : null,
      mediaPulsoUltimos7Dias: mediaPulso is num ? mediaPulso.toDouble() : null,
      totalMedicoes: json?['totalMedicoes'] is num
          ? (json?['totalMedicoes'] as num).toInt()
          : 0,
      totalForaDaFaixa: json?['totalForaDaFaixa'] is num
          ? (json?['totalForaDaFaixa'] as num).toInt()
          : 0,
      texto: json?['texto']?.toString() ??
          'Ainda nao ha medicoes suficientes para gerar uma analise.',
    );
  }

  final double? mediaUltimos7Dias;
  final double? mediaPulsoUltimos7Dias;
  final int totalMedicoes;
  final int totalForaDaFaixa;
  final String texto;
}

class OxigenacaoResumo {
  const OxigenacaoResumo({
    required this.totalRegistros,
    required this.alerta,
    required this.analise,
    required this.serie,
    this.ultima,
    this.mediaSaturacaoDia,
    this.mediaPulsoDia,
    this.proximaMedicao,
  });

  factory OxigenacaoResumo.fromJson(Map<String, dynamic> json) {
    final ultima = json['ultima'];
    final serie = json['serie'];
    final proximaMedicao = json['proximaMedicao']?.toString();
    final mediaSaturacaoDia = json['mediaSaturacaoDia'];
    final mediaPulsoDia = json['mediaPulsoDia'];

    return OxigenacaoResumo(
      ultima: ultima is Map<String, dynamic>
          ? OxigenacaoRegistro.fromJson(ultima)
          : null,
      totalRegistros: json['totalRegistros'] is num
          ? (json['totalRegistros'] as num).toInt()
          : 0,
      mediaSaturacaoDia:
          mediaSaturacaoDia is num ? mediaSaturacaoDia.toDouble() : null,
      mediaPulsoDia: mediaPulsoDia is num ? mediaPulsoDia.toDouble() : null,
      proximaMedicao: proximaMedicao == null
          ? null
          : DateTime.tryParse(proximaMedicao)?.toLocal(),
      alerta: OxigenacaoAlerta.fromJson(
        json['alerta'] is Map<String, dynamic> ? json['alerta'] : null,
      ),
      analise: OxigenacaoAnalise.fromJson(
        json['analise'] is Map<String, dynamic> ? json['analise'] : null,
      ),
      serie: serie is List
          ? serie
              .whereType<Map<String, dynamic>>()
              .map(OxigenacaoSeriePonto.fromJson)
              .toList()
          : const [],
    );
  }

  final OxigenacaoRegistro? ultima;
  final int totalRegistros;
  final double? mediaSaturacaoDia;
  final double? mediaPulsoDia;
  final DateTime? proximaMedicao;
  final OxigenacaoAlerta alerta;
  final OxigenacaoAnalise analise;
  final List<OxigenacaoSeriePonto> serie;
}

class MedicamentoHorario {
  const MedicamentoHorario({
    required this.id,
    required this.horario,
    this.quantidadeDose,
    this.unidadeDose,
    this.diasSemana = const [],
    this.frequenciaTipo = 'diaria',
  });

  factory MedicamentoHorario.fromJson(Map<String, dynamic> json) {
    final dose = json['quantidadeDose'] ?? json['quantidade_dose'];
    final diasRaw = (json['diasSemana'] ?? json['dias_semana'])?.toString();
    final horarioTexto = json['horario']?.toString() ?? '';

    return MedicamentoHorario(
      id: json['id']?.toString() ?? '',
      horario:
          horarioTexto.length > 5 ? horarioTexto.substring(0, 5) : horarioTexto,
      quantidadeDose: dose is num
          ? dose.toDouble()
          : double.tryParse(dose?.toString() ?? ''),
      unidadeDose: (json['unidadeDose'] ?? json['unidade_dose'])?.toString(),
      diasSemana: diasRaw == null || diasRaw.isEmpty
          ? const []
          : diasRaw.split(',').map((item) => item.trim()).toList(),
      frequenciaTipo:
          (json['tipoFrequencia'] ?? json['tipo_frequencia'])?.toString() ??
              'diaria',
    );
  }

  final String id;
  final String horario;
  final double? quantidadeDose;
  final String? unidadeDose;
  final List<String> diasSemana;
  final String frequenciaTipo;
}

class MedicamentoResumo {
  const MedicamentoResumo({
    required this.id,
    required this.nome,
    this.dosagem,
    this.formato,
    this.quantidadeEstoque,
    this.unidadeEstoque,
    this.alertaEstoqueBaixo,
    this.proximoHorario,
    this.proximoAtrasado = false,
    this.totalHorarios = 0,
  });

  factory MedicamentoResumo.fromJson(Map<String, dynamic> json) {
    final estoque = json['quantidadeEstoque'];
    final alerta = json['alertaEstoqueBaixo'];

    return MedicamentoResumo(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? 'Sem nome',
      dosagem: json['dosagem']?.toString(),
      formato: json['formato']?.toString(),
      quantidadeEstoque: estoque is num ? estoque.toDouble() : null,
      unidadeEstoque: json['unidadeEstoque']?.toString(),
      alertaEstoqueBaixo: alerta is num ? alerta.toDouble() : null,
      proximoHorario: json['proximoHorario']?.toString(),
      proximoAtrasado: json['proximoAtrasado'] == true,
      totalHorarios: json['totalHorarios'] is num
          ? (json['totalHorarios'] as num).toInt()
          : 0,
    );
  }

  final String id;
  final String nome;
  final String? dosagem;
  final String? formato;
  final double? quantidadeEstoque;
  final String? unidadeEstoque;
  final double? alertaEstoqueBaixo;
  final String? proximoHorario;
  final bool proximoAtrasado;
  final int totalHorarios;

  bool get estoqueBaixo =>
      quantidadeEstoque != null &&
      alertaEstoqueBaixo != null &&
      quantidadeEstoque! <= alertaEstoqueBaixo!;
}

class MedicamentosResumo {
  const MedicamentosResumo({
    required this.medicamentos,
    required this.totalMedicamentos,
    this.proximoMedicamento,
  });

  factory MedicamentosResumo.fromJson(Map<String, dynamic> json) {
    final medicamentos = json['medicamentos'];
    final proximo = json['proximoMedicamento'];

    return MedicamentosResumo(
      proximoMedicamento: proximo is Map<String, dynamic>
          ? MedicamentoResumo.fromJson(proximo)
          : null,
      medicamentos: medicamentos is List
          ? medicamentos
              .whereType<Map<String, dynamic>>()
              .map(MedicamentoResumo.fromJson)
              .toList()
          : const [],
      totalMedicamentos: json['totalMedicamentos'] is num
          ? (json['totalMedicamentos'] as num).toInt()
          : 0,
    );
  }

  final MedicamentoResumo? proximoMedicamento;
  final List<MedicamentoResumo> medicamentos;
  final int totalMedicamentos;
}

class MedicamentoDetalhe {
  const MedicamentoDetalhe({
    required this.id,
    required this.idosoId,
    required this.nome,
    this.dosagem,
    this.formato,
    this.instrucoes,
    this.dataInicio,
    this.dataFim,
    this.quantidadeEstoque,
    this.unidadeEstoque,
    this.alertaEstoqueBaixo,
    this.ativo = true,
    this.horarios = const [],
  });

  factory MedicamentoDetalhe.fromJson(
    Map<String, dynamic> json, {
    List<MedicamentoHorario> horarios = const [],
  }) {
    final estoque = json['quantidadeEstoque'] ?? json['quantidade_estoque'];
    final alerta = json['alertaEstoqueBaixo'] ?? json['alerta_estoque_baixo'];

    return MedicamentoDetalhe(
      id: json['id']?.toString() ?? '',
      idosoId: (json['idosoId'] ?? json['idoso_id'])?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      dosagem: json['dosagem']?.toString(),
      formato: json['formato']?.toString(),
      instrucoes: json['instrucoes']?.toString(),
      dataInicio: (json['dataInicio'] ?? json['data_inicio'])?.toString(),
      dataFim: (json['dataFim'] ?? json['data_fim'])?.toString(),
      quantidadeEstoque:
          estoque is num ? estoque.toDouble() : double.tryParse('$estoque'),
      unidadeEstoque:
          (json['unidadeEstoque'] ?? json['unidade_estoque'])?.toString(),
      alertaEstoqueBaixo:
          alerta is num ? alerta.toDouble() : double.tryParse('$alerta'),
      ativo: json['ativo'] is bool ? json['ativo'] as bool : true,
      horarios: horarios,
    );
  }

  final String id;
  final String idosoId;
  final String nome;
  final String? dosagem;
  final String? formato;
  final String? instrucoes;
  final String? dataInicio;
  final String? dataFim;
  final double? quantidadeEstoque;
  final String? unidadeEstoque;
  final double? alertaEstoqueBaixo;
  final bool ativo;
  final List<MedicamentoHorario> horarios;
}

class HistoricoMedicamentoEntrada {
  const HistoricoMedicamentoEntrada({
    required this.id,
    required this.usuarioNome,
    required this.medicamentoNome,
    required this.descricao,
    required this.dataHora,
    required this.badge,
  });

  factory HistoricoMedicamentoEntrada.fromJson(Map<String, dynamic> json) {
    return HistoricoMedicamentoEntrada(
      id: json['id']?.toString() ?? '',
      usuarioNome: json['usuarioNome']?.toString() ?? 'Cuidador',
      medicamentoNome: json['medicamentoNome']?.toString() ?? 'Medicamento',
      descricao: json['descricao']?.toString() ?? '',
      dataHora: (DateTime.tryParse(json['dataHora']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      badge: GlicemiaHistoricoBadge.fromJson(
        json['badge'] is Map<String, dynamic> ? json['badge'] : null,
      ),
    );
  }

  final String id;
  final String usuarioNome;
  final String medicamentoNome;
  final String descricao;
  final DateTime dataHora;
  final GlicemiaHistoricoBadge badge;
}

class InsumoResumo {
  const InsumoResumo({
    required this.id,
    required this.idosoId,
    required this.nome,
    required this.tipoUnidade,
    required this.quantidadeUnidades,
    this.quantidadePorUnidade,
    this.alertaMinimoUnidades,
    this.consumoMedioDiario,
    this.dataValidade,
    this.diasAlertaValidade = 7,
    this.fotoUrl,
    this.localArmazenamento,
    this.frequenciaUso,
    this.observacoes,
  });

  factory InsumoResumo.fromJson(Map<String, dynamic> json) {
    return InsumoResumo(
      id: json['id']?.toString() ?? '',
      idosoId:
          json['idosoId']?.toString() ?? json['idoso_id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? 'Insumo',
      tipoUnidade: json['tipoUnidade']?.toString() ??
          json['tipo_unidade']?.toString() ??
          '',
      quantidadePorUnidade: _numOrNull(
        json['quantidadePorUnidade'] ?? json['quantidade_por_unidade'],
      ),
      quantidadeUnidades: _numOrNull(
            json['quantidadeUnidades'] ?? json['quantidade_unidades'],
          ) ??
          0,
      alertaMinimoUnidades: _numOrNull(
        json['alertaMinimoUnidades'] ?? json['alerta_minimo_unidades'],
      ),
      consumoMedioDiario: _numOrNull(
        json['consumoMedioDiario'] ?? json['consumo_medio_diario'],
      ),
      dataValidade: _dateOnlyOrNull(
        json['dataValidade'] ?? json['data_validade'],
      ),
      diasAlertaValidade: _intOrNull(
            json['diasAlertaValidade'] ?? json['dias_alerta_validade'],
          ) ??
          7,
      fotoUrl: json['fotoUrl']?.toString() ?? json['foto_url']?.toString(),
      localArmazenamento: json['localArmazenamento']?.toString() ??
          json['local_armazenamento']?.toString(),
      frequenciaUso: json['frequenciaUso']?.toString() ??
          json['frequencia_uso']?.toString(),
      observacoes: json['observacoes']?.toString(),
    );
  }

  final String id;
  final String idosoId;
  final String nome;
  final String tipoUnidade;
  final double? quantidadePorUnidade;
  final double quantidadeUnidades;
  final double? alertaMinimoUnidades;
  final double? consumoMedioDiario;
  final DateTime? dataValidade;
  final int diasAlertaValidade;
  final String? fotoUrl;
  final String? localArmazenamento;
  final String? frequenciaUso;
  final String? observacoes;

  InsumoResumo copyWith({
    double? quantidadeUnidades,
    String? fotoUrl,
    DateTime? dataValidade,
  }) {
    return InsumoResumo(
      id: id,
      idosoId: idosoId,
      nome: nome,
      tipoUnidade: tipoUnidade,
      quantidadePorUnidade: quantidadePorUnidade,
      quantidadeUnidades: quantidadeUnidades ?? this.quantidadeUnidades,
      alertaMinimoUnidades: alertaMinimoUnidades,
      consumoMedioDiario: consumoMedioDiario,
      dataValidade: dataValidade ?? this.dataValidade,
      diasAlertaValidade: diasAlertaValidade,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      localArmazenamento: localArmazenamento,
      frequenciaUso: frequenciaUso,
      observacoes: observacoes,
    );
  }
}

class AlimentoConsumido {
  const AlimentoConsumido({
    required this.nome,
    this.pesoGramas,
    this.calorias,
  });

  factory AlimentoConsumido.fromJson(Map<String, dynamic> json) {
    return AlimentoConsumido(
      nome: json['nome']?.toString() ?? '',
      pesoGramas: _numOrNull(json['pesoGramas'] ?? json['peso_gramas']),
      calorias: _numOrNull(json['calorias']),
    );
  }

  final String nome;
  final double? pesoGramas;
  final double? calorias;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        if (pesoGramas != null) 'pesoGramas': pesoGramas,
        if (calorias != null) 'calorias': calorias,
      };
}

class RefeicaoResumo {
  const RefeicaoResumo({
    required this.id,
    required this.idosoId,
    required this.tipoRefeicao,
    required this.alimentos,
    required this.aceitacao,
    this.dataConsumo,
    this.horaConsumo,
    this.observacoes,
    this.registradoPorId,
    this.concluidaEm,
  });

  factory RefeicaoResumo.fromJson(Map<String, dynamic> json) {
    final alimentosJson = json['alimentos'];
    return RefeicaoResumo(
      id: json['id']?.toString() ?? '',
      idosoId:
          json['idosoId']?.toString() ?? json['idoso_id']?.toString() ?? '',
      tipoRefeicao: json['tipoRefeicao']?.toString() ??
          json['tipo_refeicao']?.toString() ??
          'Refeicao',
      alimentos: alimentosJson is List
          ? alimentosJson
              .whereType<Map<String, dynamic>>()
              .map(AlimentoConsumido.fromJson)
              .where((item) => item.nome.isNotEmpty)
              .toList()
          : const [],
      aceitacao: json['aceitacao']?.toString() ?? '',
      dataConsumo: _dateOnlyOrNull(
        json['dataConsumo'] ?? json['data_consumo'],
      ),
      horaConsumo:
          json['horaConsumo']?.toString() ?? json['hora_consumo']?.toString(),
      observacoes: json['observacoes']?.toString(),
      registradoPorId: json['registradoPorId']?.toString() ??
          json['registrado_por_id']?.toString(),
      concluidaEm: DateTime.tryParse(
        json['concluidaEm']?.toString() ??
            json['concluida_em']?.toString() ??
            '',
      ),
    );
  }

  final String id;
  final String idosoId;
  final String tipoRefeicao;
  final List<AlimentoConsumido> alimentos;
  final String aceitacao;
  final DateTime? dataConsumo;
  final String? horaConsumo;
  final String? observacoes;
  final String? registradoPorId;
  final DateTime? concluidaEm;

  bool get concluida => concluidaEm != null;
}

class HidratacaoRegistro {
  const HidratacaoRegistro({
    required this.id,
    required this.idosoId,
    required this.quantidadeMl,
    required this.registradoEm,
  });

  factory HidratacaoRegistro.fromJson(Map<String, dynamic> json) {
    return HidratacaoRegistro(
      id: json['id']?.toString() ?? '',
      idosoId:
          json['idosoId']?.toString() ?? json['idoso_id']?.toString() ?? '',
      quantidadeMl:
          _numOrNull(json['quantidadeMl'] ?? json['quantidade_ml']) ?? 0,
      registradoEm: DateTime.tryParse(
            json['registradoEm']?.toString() ??
                json['registrado_em']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }

  final String id;
  final String idosoId;
  final double quantidadeMl;
  final DateTime registradoEm;
}

class HistoricoRegistro {
  const HistoricoRegistro({
    required this.id,
    required this.acao,
    required this.tipoEntidade,
    required this.entidadeId,
    required this.usuarioNome,
    required this.criadoEm,
    required this.itemNome,
    required this.dadosNovos,
    required this.dadosAnteriores,
    this.usuarioId,
  });

  factory HistoricoRegistro.fromJson(Map<String, dynamic> json) {
    return HistoricoRegistro(
      id: json['id']?.toString() ?? '',
      acao: json['acao']?.toString() ?? '',
      tipoEntidade: json['tipoEntidade']?.toString() ??
          json['tipo_entidade']?.toString() ??
          '',
      entidadeId: json['entidadeId']?.toString() ??
          json['entidade_id']?.toString() ??
          '',
      usuarioId:
          json['usuarioId']?.toString() ?? json['usuario_id']?.toString(),
      usuarioNome: json['usuarioNome']?.toString() ??
          json['usuario_nome']?.toString() ??
          'Usuario',
      criadoEm: DateTime.tryParse(
            json['criadoEm']?.toString() ?? json['criado_em']?.toString() ?? '',
          ) ??
          DateTime.now(),
      itemNome: json['itemNome']?.toString() ??
          json['item_nome']?.toString() ??
          'Registro',
      dadosNovos: _mapOrEmpty(json['dadosNovos'] ?? json['dados_novos']),
      dadosAnteriores:
          _mapOrEmpty(json['dadosAnteriores'] ?? json['dados_anteriores']),
    );
  }

  final String id;
  final String acao;
  final String tipoEntidade;
  final String entidadeId;
  final String? usuarioId;
  final String usuarioNome;
  final DateTime criadoEm;
  final String itemNome;
  final Map<String, dynamic> dadosNovos;
  final Map<String, dynamic> dadosAnteriores;
}

class ConviteFicha {
  const ConviteFicha({required this.codigo, this.expiraEm});

  factory ConviteFicha.fromJson(Map<String, dynamic> json) {
    final expira = json['expira_em']?.toString() ?? json['expiraEm']?.toString();
    return ConviteFicha(
      codigo: json['codigo']?.toString() ?? '',
      expiraEm: expira == null ? null : DateTime.tryParse(expira),
    );
  }

  final String codigo;
  final DateTime? expiraEm;
}

class MembroFicha {
  const MembroFicha({
    required this.usuarioId,
    required this.nome,
    required this.eAdministrador,
    required this.eCriador,
    required this.permissoesVisualizar,
    required this.permissoesEditar,
    this.id,
    this.urlFoto,
    this.telefone,
    this.funcao,
    this.relacao,
  });

  factory MembroFicha.fromJson(Map<String, dynamic> json) {
    final permissoes = json['permissoes'];
    final visualizar = permissoes is Map ? permissoes['visualizar'] : null;
    final editar = permissoes is Map ? permissoes['editar'] : null;

    return MembroFicha(
      id: json['id']?.toString(),
      usuarioId: json['usuario_id']?.toString() ?? '',
      nome: json['usuario_nome']?.toString() ?? 'Sem nome',
      urlFoto: json['usuario_foto']?.toString(),
      telefone: json['usuario_telefone']?.toString(),
      funcao: json['funcao']?.toString(),
      relacao: json['relacao']?.toString(),
      eAdministrador: json['e_administrador'] == true,
      eCriador: json['e_criador'] == true,
      permissoesVisualizar: visualizar is List
          ? visualizar.map((item) => item.toString()).toList()
          : <String>[],
      permissoesEditar: editar is List
          ? editar.map((item) => item.toString()).toList()
          : <String>[],
    );
  }

  final String? id;
  final String usuarioId;
  final String nome;
  final String? urlFoto;
  final String? telefone;
  final String? funcao;
  final String? relacao;
  final bool eAdministrador;
  final bool eCriador;
  final List<String> permissoesVisualizar;
  final List<String> permissoesEditar;
}

class SolicitacaoPendente {
  const SolicitacaoPendente({
    required this.id,
    required this.usuarioId,
    required this.nome,
    required this.criadoEm,
    this.urlFoto,
    this.funcao,
  });

  factory SolicitacaoPendente.fromJson(Map<String, dynamic> json) {
    return SolicitacaoPendente(
      id: json['id']?.toString() ?? '',
      usuarioId: json['usuario_id']?.toString() ?? '',
      nome: json['usuario_nome']?.toString() ?? 'Sem nome',
      urlFoto: json['usuario_foto']?.toString(),
      funcao: json['funcao']?.toString(),
      criadoEm:
          DateTime.tryParse(json['criado_em']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  final String id;
  final String usuarioId;
  final String nome;
  final String? urlFoto;
  final String? funcao;
  final DateTime criadoEm;
}

class _ApiMemoryCache<T> {
  const _ApiMemoryCache({
    required this.value,
    required this.createdAt,
  });

  final T value;
  final DateTime createdAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  final Dio _dio;
  final _agendaCache = <String, _ApiMemoryCache<List<Map<String, dynamic>>>>{};
  final _agendaHistoryCache =
      <String, _ApiMemoryCache<List<Map<String, dynamic>>>>{};
  final _equipmentsCache =
      <String, _ApiMemoryCache<List<Map<String, dynamic>>>>{};
  final _equipmentsHistoryCache =
      <String, _ApiMemoryCache<List<Map<String, dynamic>>>>{};
  final _equipmentMaintenancesCache =
      <String, _ApiMemoryCache<List<Map<String, dynamic>>>>{};
  static const _agendaCacheTtl = Duration(minutes: 2);

  void _clearAgendaCaches() {
    _agendaCache.clear();
    _agendaHistoryCache.clear();
  }

  void _clearEquipmentCaches() {
    _equipmentsCache.clear();
    _equipmentsHistoryCache.clear();
    _equipmentMaintenancesCache.clear();
  }

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>(ApiEndpoints.health);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao consultar a API.');
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {
          'email': email,
          'senha': senha,
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao entrar.');
    }
  }

  Future<Map<String, dynamic>> loginGoogle({
    required String idToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loginGoogle,
        data: {'idToken': idToken},
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao entrar com Google.');
    }
  }

  Future<Map<String, dynamic>> cadastrarGoogle({
    required String idToken,
    required String nome,
    required String telefone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.cadastroGoogle,
        data: {
          'idToken': idToken,
          'nome': nome,
          'telefone': telefone,
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao cadastrar com Google.',
      );
    }
  }

  Future<Map<String, dynamic>> cadastrar({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.cadastro,
        data: {
          'nome': nome,
          'email': email,
          'telefone': telefone,
          'senha': senha,
          'tipoUsuario': 'cuidador',
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao criar conta.');
    }
  }

  Future<Map<String, dynamic>> atualizarUsuario({
    required String id,
    String? nome,
    String? email,
    String? telefone,
    String? urlFoto,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.usuario(id),
        data: {
          if (nome != null && nome.isNotEmpty) 'nome': nome,
          if (email != null && email.isNotEmpty) 'email': email,
          if (telefone != null) 'telefone': telefone,
          if (urlFoto != null && urlFoto.isNotEmpty) 'urlFoto': urlFoto,
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar usuario.');
    }
  }

  Future<List<IdosoResumo>> listarIdosos({String? usuarioId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.idosos,
        queryParameters: {
          if (usuarioId != null && usuarioId.isNotEmpty) 'usuarioId': usuarioId,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(IdosoResumo.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar fichas.');
    }
  }

  Future<IdosoResumo> buscarIdoso({required String idosoId}) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>(ApiEndpoints.idoso(idosoId));
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return IdosoResumo.fromJson(dados);
      }
      throw const ApiException('Ficha nao encontrada.');
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao buscar ficha.');
    }
  }

  Future<Map<String, dynamic>> criarIdoso({
    required String nomeCompleto,
    String? criadoPorId,
    String? dataNascimento,
    String? urlFoto,
    String? sexo,
    String? tipoSanguineo,
    List<String>? condicoesSaude,
    List<String>? monitoramentos,
    String? limitacoes,
    String? alergiasRestricoes,
    String? observacoesGerais,
    String? contatoEmergenciaNome,
    String? contatoEmergenciaTelefone,
    String? contatoEmergenciaParentesco,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.idosos,
        data: {
          'nomeCompleto': nomeCompleto,
          if (dataNascimento != null && dataNascimento.isNotEmpty)
            'dataNascimento': dataNascimento,
          if (urlFoto != null && urlFoto.isNotEmpty) 'urlFoto': urlFoto,
          if (criadoPorId != null && criadoPorId.isNotEmpty)
            'criadoPorId': criadoPorId,
          if (sexo != null && sexo.isNotEmpty) 'sexo': sexo,
          if (tipoSanguineo != null && tipoSanguineo.isNotEmpty)
            'tipoSanguineo': tipoSanguineo,
          if (condicoesSaude != null && condicoesSaude.isNotEmpty)
            'condicoesSaude': condicoesSaude,
          if (monitoramentos != null && monitoramentos.isNotEmpty)
            'monitoramentos': monitoramentos,
          if (limitacoes != null && limitacoes.isNotEmpty)
            'limitacoes': limitacoes,
          if (alergiasRestricoes != null && alergiasRestricoes.isNotEmpty)
            'alergiasRestricoes': alergiasRestricoes,
          if (observacoesGerais != null && observacoesGerais.isNotEmpty)
            'observacoesGerais': observacoesGerais,
          if (contatoEmergenciaNome != null && contatoEmergenciaNome.isNotEmpty)
            'contatoEmergenciaNome': contatoEmergenciaNome,
          if (contatoEmergenciaTelefone != null &&
              contatoEmergenciaTelefone.isNotEmpty)
            'contatoEmergenciaTelefone': contatoEmergenciaTelefone,
          if (contatoEmergenciaParentesco != null &&
              contatoEmergenciaParentesco.isNotEmpty)
            'contatoEmergenciaParentesco': contatoEmergenciaParentesco,
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao criar ficha.');
    }
  }

  Future<String> gerarConviteIdoso({
    required String idosoId,
    String? convidadoPorId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.convites,
        data: {
          'idosoId': idosoId,
          if (convidadoPorId != null && convidadoPorId.isNotEmpty)
            'convidadoPorId': convidadoPorId,
        },
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return dados['codigo']?.toString() ?? '';
      }
      return '';
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao gerar codigo de convite.',
      );
    }
  }

  Future<String> aceitarConviteIdoso({
    required String codigo,
    required String usadoPorId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.convitesAceitar,
        data: {
          'codigo': codigo,
          'usadoPorId': usadoPorId,
        },
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        final convite = dados['convite'];
        if (convite is Map<String, dynamic>) {
          return convite['idoso_id']?.toString() ??
              convite['idosoId']?.toString() ??
              '';
        }
      }
      return '';
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Nao foi possivel acessar a ficha com esse codigo.',
      );
    }
  }

  Future<List<IdosoResumo>> listarIdososAdministrados({
    required String usuarioId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.idososAdministrados,
        queryParameters: {'usuarioId': usuarioId},
      );
      final data = response.data?['dados'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(IdosoResumo.fromJson)
            .toList();
      }
      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao listar fichas administradas.',
      );
    }
  }

  Future<ConviteFicha> obterConviteFicha({
    required String idosoId,
    String? usuarioId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.convites,
        data: {
          'idosoId': idosoId,
          if (usuarioId != null && usuarioId.isNotEmpty)
            'convidadoPorId': usuarioId,
        },
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return ConviteFicha.fromJson(dados);
      }
      return const ConviteFicha(codigo: '');
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao gerar link de compartilhamento.',
      );
    }
  }

  Future<List<MembroFicha>> listarParticipantes({
    required String idosoId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.membrosParticipantes,
        queryParameters: {'idosoId': idosoId},
      );
      final data = response.data?['dados'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(MembroFicha.fromJson)
            .toList();
      }
      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar participantes.');
    }
  }

  Future<List<SolicitacaoPendente>> listarSolicitacoesPendentes({
    required String idosoId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.membrosPendentes,
        queryParameters: {'idosoId': idosoId},
      );
      final data = response.data?['dados'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(SolicitacaoPendente.fromJson)
            .toList();
      }
      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao listar solicitacoes pendentes.',
      );
    }
  }

  Future<void> aprovarSolicitacao({
    required String membroId,
    String? usuarioId,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.membroAprovar(membroId),
        data: {
          if (usuarioId != null && usuarioId.isNotEmpty) 'usuarioId': usuarioId,
        },
      );
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao aprovar solicitacao.');
    }
  }

  Future<void> negarSolicitacao({
    required String membroId,
    String? usuarioId,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.membroNegar(membroId),
        data: {
          if (usuarioId != null && usuarioId.isNotEmpty) 'usuarioId': usuarioId,
        },
      );
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao negar solicitacao.');
    }
  }

  Future<void> revogarAcessoMembro({
    required String membroId,
    String? usuarioId,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.membroRevogar(membroId),
        data: {
          if (usuarioId != null && usuarioId.isNotEmpty) 'usuarioId': usuarioId,
        },
      );
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao revogar acesso.');
    }
  }

  Future<MembroFicha> buscarMembro({required String membroId}) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>(ApiEndpoints.membro(membroId));
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return MembroFicha.fromJson(dados);
      }
      throw const ApiException('Membro nao encontrado.');
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao buscar membro.');
    }
  }

  Future<MembroFicha> atualizarMembro({
    required String membroId,
    String? funcao,
    String? relacao,
    bool? eAdministrador,
    List<String>? visualizar,
    List<String>? editar,
    String? atualizadoPorId,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.membro(membroId),
        data: {
          if (funcao != null) 'funcao': funcao,
          if (relacao != null) 'relacao': relacao,
          if (eAdministrador != null) 'eAdministrador': eAdministrador,
          if (visualizar != null || editar != null)
            'permissoes': {
              'visualizar': visualizar ?? const [],
              'editar': editar ?? const [],
            },
          if (atualizadoPorId != null && atualizadoPorId.isNotEmpty)
            'atualizadoPorId': atualizadoPorId,
        },
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return MembroFicha.fromJson(dados);
      }
      throw const ApiException('Nao foi possivel atualizar o membro.');
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar membro.');
    }
  }

  Future<Map<String, dynamic>> atualizarMonitoramentosIdoso({
    required String id,
    required List<String> monitoramentos,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.idoso(id),
        data: {
          'monitoramentos': monitoramentos,
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao atualizar monitoramentos.',
      );
    }
  }

  Future<Map<String, dynamic>> atualizarIdoso({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.idoso(id),
        data: data,
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar ficha.');
    }
  }

  Future<List<RefeicaoResumo>> listarRefeicoes({String? idosoId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.refeicoes,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(RefeicaoResumo.fromJson)
            .toList();
      }
      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar refeicoes.');
    }
  }

  Future<String> buscarDicaAlimentacao() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.dicaAlimentacao,
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return dados['texto']?.toString() ??
            'Refeicoes nutritivas fazem toda a diferenca.';
      }
      return 'Refeicoes nutritivas fazem toda a diferenca.';
    } on DioException {
      return 'Refeicoes nutritivas fazem toda a diferenca.';
    }
  }

  Future<String> buscarDicaDashboard({required String idosoId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.dicaDashboard(idosoId),
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return dados['texto']?.toString() ??
            'Incentive pequenas pausas e hidratacao ao longo do dia.';
      }
      return 'Incentive pequenas pausas e hidratacao ao longo do dia.';
    } on DioException {
      return 'Incentive pequenas pausas e hidratacao ao longo do dia.';
    }
  }

  Future<RefeicaoResumo> criarRefeicao({
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refeicoes,
        data: data,
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) return RefeicaoResumo.fromJson(dados);
      return RefeicaoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao salvar refeicao.');
    }
  }

  Future<RefeicaoResumo> atualizarRefeicao({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.refeicao(id),
        data: data,
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) return RefeicaoResumo.fromJson(dados);
      return RefeicaoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar refeicao.');
    }
  }

  Future<RefeicaoResumo> concluirRefeicao({
    required String id,
    String? usuarioId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.concluirRefeicao(id),
        data: {
          if (usuarioId != null && usuarioId.isNotEmpty) 'usuarioId': usuarioId,
        },
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) return RefeicaoResumo.fromJson(dados);
      return RefeicaoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao concluir refeicao.');
    }
  }

  Future<List<HidratacaoRegistro>> listarHidratacoes({String? idosoId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.hidratacoes,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(HidratacaoRegistro.fromJson)
            .toList();
      }
      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar hidratacoes.');
    }
  }

  Future<void> criarHidratacao({
    required String idosoId,
    required double quantidadeMl,
    String? registradoPorId,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.hidratacoes,
        data: {
          'idosoId': idosoId,
          'quantidadeMl': quantidadeMl,
          'registradoEm': DateTime.now().toUtc().toIso8601String(),
          if (registradoPorId != null && registradoPorId.isNotEmpty)
            'registradoPorId': registradoPorId,
        },
      );
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao registrar agua.');
    }
  }

  Future<List<AiConversa>> listarConversasIa({
    required String usuarioId,
    String? idosoId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.iaConversas,
        queryParameters: {
          'usuarioId': usuarioId,
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AiConversa.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Nao foi possivel carregar os chats.',
      );
    }
  }

  Future<AiConversa> criarConversaIa({
    required String usuarioId,
    String? idosoId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.iaConversas,
        data: {
          'usuarioId': usuarioId,
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'titulo': 'Novo chat',
        },
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) return AiConversa.fromJson(dados);
      return AiConversa.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Nao foi possivel criar um novo chat.',
      );
    }
  }

  Future<List<AiMensagem>> listarMensagensIa({
    required String conversaId,
    required String usuarioId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.iaMensagens(conversaId),
        queryParameters: {'usuarioId': usuarioId},
      );
      final data = response.data?['dados'];

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AiMensagem.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Nao foi possivel abrir este chat.',
      );
    }
  }

  Future<AiPerguntaResposta> perguntarIa({
    required String usuarioId,
    required String mensagem,
    String? conversaId,
    String? idosoId,
    Map<String, String>? imagem,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.iaPerguntar,
        data: {
          'usuarioId': usuarioId,
          'mensagem': mensagem,
          if (conversaId != null && conversaId.isNotEmpty)
            'conversaId': conversaId,
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          if (imagem != null) 'anexos': [imagem],
        },
      );

      return AiPerguntaResposta.fromJson(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Nao foi possivel falar com a IA agora.',
      );
    }
  }

  Future<AiRelatorioInicial> obterRelatorioInicialIa({
    required String usuarioId,
    required String idosoId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.iaRelatorioInicial,
        queryParameters: {
          'usuarioId': usuarioId,
          'idosoId': idosoId,
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return AiRelatorioInicial.fromJson(dados);
      }

      return AiRelatorioInicial.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Nao foi possivel carregar o relatorio da IA.',
      );
    }
  }

  Future<List<InsumoResumo>> listarInsumos({
    String? idosoId,
    String filtro = 'todos',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.insumos,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'filtro': filtro,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(InsumoResumo.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar insumos.');
    }
  }

  Future<InsumoResumo> criarInsumo({
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.insumos,
        data: data,
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) return InsumoResumo.fromJson(dados);
      return InsumoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao criar insumo.');
    }
  }

  Future<InsumoResumo> atualizarInsumo({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.insumo(id),
        data: data,
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) return InsumoResumo.fromJson(dados);
      return InsumoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar insumo.');
    }
  }

  Future<void> removerInsumo({required String id}) async {
    try {
      await _dio.delete<void>(ApiEndpoints.insumo(id));
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao excluir insumo.');
    }
  }

  Future<InsumoResumo> movimentarInsumo({
    required String id,
    required String tipo,
    required double quantidade,
    required String motivo,
    String? usuarioId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.movimentacoesInsumo(id),
        data: {
          'tipo': tipo,
          'quantidade': quantidade,
          'motivo': motivo,
          if (usuarioId != null && usuarioId.isNotEmpty) 'usuarioId': usuarioId,
        },
      );
      final dados = response.data?['dados'];
      if (dados is Map<String, dynamic>) {
        return InsumoResumo.fromJson({
          ...dados,
          'id': id,
          'quantidadeUnidades': dados['quantidadeAtual'],
        });
      }
      return InsumoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar estoque.');
    }
  }

  Future<Map<String, dynamic>> criarHumor({
    required String idosoId,
    required String humor,
    required String dataHumor,
    required String horarioRegi,
    required String registradoPorId,
    String? observacoes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.humores,
        data: {
          'idosoId': idosoId,
          'humor': humor,
          'dataHumor': dataHumor,
          'horarioRegi': horarioRegi,
          'registradoPorId': registradoPorId,
          if (observacoes != null && observacoes.trim().isNotEmpty)
            'observacoes': observacoes.trim(),
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao salvar humor.');
    }
  }

  Future<List<Map<String, dynamic>>> listarHumores({String? idosoId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.humores,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar humores.');
    }
  }

  Future<List<HistoricoRegistro>> listarHistorico({
    required String tipo,
    required String idosoId,
    required String inicio,
    required String fim,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.historico,
        queryParameters: {
          'tipo': tipo,
          'idosoId': idosoId,
          'inicio': inicio,
          'fim': fim,
          'limite': 200,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(HistoricoRegistro.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar historico.');
    }
  }

  Future<List<Map<String, dynamic>>> listarCompromissos({
    String? idosoId,
  }) async {
    final cacheKey = idosoId ?? '';
    final cached = _agendaCache[cacheKey];
    if (cached != null && cached.isFresh(_agendaCacheTtl)) {
      return List<Map<String, dynamic>>.from(cached.value);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.agenda,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        final result = data.whereType<Map<String, dynamic>>().toList();
        _agendaCache[cacheKey] = _ApiMemoryCache(
          value: result,
          createdAt: DateTime.now(),
        );
        return List<Map<String, dynamic>>.from(result);
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar compromissos.');
    }
  }

  Future<List<Map<String, dynamic>>> listarHistoricoAgenda({
    String? idosoId,
  }) async {
    final cacheKey = idosoId ?? '';
    final cached = _agendaHistoryCache[cacheKey];
    if (cached != null && cached.isFresh(_agendaCacheTtl)) {
      return List<Map<String, dynamic>>.from(cached.value);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.agendaHistorico,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        final result = data.whereType<Map<String, dynamic>>().toList();
        _agendaHistoryCache[cacheKey] = _ApiMemoryCache(
          value: result,
          createdAt: DateTime.now(),
        );
        return List<Map<String, dynamic>>.from(result);
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao listar historico da agenda.',
      );
    }
  }

  Future<Map<String, dynamic>> criarCompromisso({
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.agenda,
        data: data,
      );
      _clearAgendaCaches();
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao criar compromisso.');
    }
  }

  Future<Map<String, dynamic>> atualizarCompromisso({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.compromisso(id),
        data: data,
      );
      _clearAgendaCaches();
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar compromisso.');
    }
  }

  Future<Map<String, dynamic>> atualizarOcorrenciaCompromisso({
    required String id,
    required String dataOcorrencia,
    required String status,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.ocorrenciaCompromisso(id),
        data: {
          'dataOcorrencia': dataOcorrencia,
          'status': status,
        },
      );
      _clearAgendaCaches();
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao atualizar ocorrencia do compromisso.',
      );
    }
  }

  Future<void> removerCompromisso({required String id}) async {
    try {
      await _dio.delete<void>(ApiEndpoints.compromisso(id));
      _clearAgendaCaches();
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao excluir compromisso.');
    }
  }

  Future<List<Map<String, dynamic>>> listarEquipamentos({
    String? idosoId,
  }) async {
    final cacheKey = idosoId ?? '';
    final cached = _equipmentsCache[cacheKey];
    if (cached != null && cached.isFresh(_agendaCacheTtl)) {
      return List<Map<String, dynamic>>.from(cached.value);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.equipamentos,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        final result = data.whereType<Map<String, dynamic>>().toList();
        _equipmentsCache[cacheKey] = _ApiMemoryCache(
          value: result,
          createdAt: DateTime.now(),
        );
        return List<Map<String, dynamic>>.from(result);
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar equipamentos.');
    }
  }

  Future<List<Map<String, dynamic>>> listarHistoricoEquipamentos({
    String? idosoId,
  }) async {
    final cacheKey = idosoId ?? '';
    final cached = _equipmentsHistoryCache[cacheKey];
    if (cached != null && cached.isFresh(_agendaCacheTtl)) {
      return List<Map<String, dynamic>>.from(cached.value);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.equipamentosHistorico,
        queryParameters: {
          if (idosoId != null && idosoId.isNotEmpty) 'idosoId': idosoId,
          'limite': 100,
        },
      );
      final data = response.data?['dados'];

      if (data is List) {
        final result = data.whereType<Map<String, dynamic>>().toList();
        _equipmentsHistoryCache[cacheKey] = _ApiMemoryCache(
          value: result,
          createdAt: DateTime.now(),
        );
        return List<Map<String, dynamic>>.from(result);
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao listar historico de equipamentos.',
      );
    }
  }

  Future<Map<String, dynamic>> criarEquipamento({
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.equipamentos,
        data: data,
      );
      _clearEquipmentCaches();
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao criar equipamento.');
    }
  }

  Future<Map<String, dynamic>> atualizarEquipamento({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.equipamento(id),
        data: data,
      );
      _clearEquipmentCaches();
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar equipamento.');
    }
  }

  Future<void> removerEquipamento({required String id}) async {
    try {
      await _dio.delete<void>(ApiEndpoints.equipamento(id));
      _clearEquipmentCaches();
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao excluir equipamento.');
    }
  }

  Future<List<Map<String, dynamic>>> listarManutencoesEquipamento({
    required String id,
  }) async {
    final cached = _equipmentMaintenancesCache[id];
    if (cached != null && cached.isFresh(_agendaCacheTtl)) {
      return List<Map<String, dynamic>>.from(cached.value);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.manutencoesEquipamento(id),
      );
      final data = response.data?['dados'];

      if (data is List) {
        final result = data.whereType<Map<String, dynamic>>().toList();
        _equipmentMaintenancesCache[id] = _ApiMemoryCache(
          value: result,
          createdAt: DateTime.now(),
        );
        return List<Map<String, dynamic>>.from(result);
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao listar manutencoes.',
      );
    }
  }

  Future<Map<String, dynamic>> registrarManutencaoEquipamento({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.manutencoesEquipamento(id),
        data: data,
      );
      _clearEquipmentCaches();
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao registrar manutencao.',
      );
    }
  }

  Future<GlicemiaResumo> getResumoGlicemia({
    required String idosoId,
    DateTime? dataReferencia,
    String periodo = 'dia',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.glicemiaResumo,
        queryParameters: {
          'idosoId': idosoId,
          'periodo': periodo,
          if (dataReferencia != null)
            'dataReferencia': _toIsoDateOnly(dataReferencia),
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return GlicemiaResumo.fromJson(dados);
      }

      return GlicemiaResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar glicemia.',
      );
    }
  }

  Future<List<GlicemiaHistoricoEntrada>> getHistoricoGlicemia({
    required String idosoId,
    DateTime? dataReferencia,
    String periodo = 'dia',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.glicemiaHistorico,
        queryParameters: {
          'idosoId': idosoId,
          'periodo': periodo,
          if (dataReferencia != null)
            'dataReferencia': _toIsoDateOnly(dataReferencia),
        },
      );
      final dados = response.data?['dados'];

      if (dados is List) {
        return dados
            .whereType<Map<String, dynamic>>()
            .map(GlicemiaHistoricoEntrada.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar histórico de glicemia.',
      );
    }
  }

  Future<GlicemiaRegistro> criarGlicemia({
    required String idosoId,
    required int valor,
    required String contexto,
    required DateTime medidoEm,
    String? observacoes,
    String? sintomas,
    String? registradoPorId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.glicemias,
        data: {
          'idosoId': idosoId,
          'valor': valor,
          'contexto': contexto,
          'medidoEm': medidoEm.toUtc().toIso8601String(),
          if (observacoes != null && observacoes.isNotEmpty)
            'observacoes': observacoes,
          if (sintomas != null && sintomas.isNotEmpty) 'sintomas': sintomas,
          if (registradoPorId != null && registradoPorId.isNotEmpty)
            'registradoPorId': registradoPorId,
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return GlicemiaRegistro.fromJson(dados);
      }

      return GlicemiaRegistro.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao registrar glicemia.',
      );
    }
  }

  Future<PressaoResumo> getResumoPressao({
    required String idosoId,
    DateTime? dataReferencia,
    String periodo = 'dia',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.pressaoResumo,
        queryParameters: {
          'idosoId': idosoId,
          'periodo': periodo,
          if (dataReferencia != null)
            'dataReferencia': _toIsoDateOnly(dataReferencia),
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return PressaoResumo.fromJson(dados);
      }

      return PressaoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar pressão.',
      );
    }
  }

  Future<List<PressaoHistoricoEntrada>> getHistoricoPressao({
    required String idosoId,
    DateTime? dataReferencia,
    String periodo = 'dia',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.pressaoHistorico,
        queryParameters: {
          'idosoId': idosoId,
          'periodo': periodo,
          if (dataReferencia != null)
            'dataReferencia': _toIsoDateOnly(dataReferencia),
        },
      );
      final dados = response.data?['dados'];

      if (dados is List) {
        return dados
            .whereType<Map<String, dynamic>>()
            .map(PressaoHistoricoEntrada.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar histórico de pressão.',
      );
    }
  }

  Future<PressaoRegistro> criarPressao({
    required String idosoId,
    required int sistolica,
    required int diastolica,
    required DateTime medidoEm,
    int? batimentos,
    String? observacoes,
    String? registradoPorId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.pressao,
        data: {
          'idosoId': idosoId,
          'sistolica': sistolica,
          'diastolica': diastolica,
          'medidoEm': medidoEm.toUtc().toIso8601String(),
          if (batimentos != null) 'batimentos': batimentos,
          if (observacoes != null && observacoes.isNotEmpty)
            'observacoes': observacoes,
          if (registradoPorId != null && registradoPorId.isNotEmpty)
            'registradoPorId': registradoPorId,
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return PressaoRegistro.fromJson(dados);
      }

      return PressaoRegistro.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao registrar pressão.',
      );
    }
  }

  Future<OxigenacaoResumo> getResumoOxigenacao({
    required String idosoId,
    DateTime? dataReferencia,
    String periodo = 'dia',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.oxigenacaoResumo,
        queryParameters: {
          'idosoId': idosoId,
          'periodo': periodo,
          if (dataReferencia != null)
            'dataReferencia': _toIsoDateOnly(dataReferencia),
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return OxigenacaoResumo.fromJson(dados);
      }

      return OxigenacaoResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar oxigenação.',
      );
    }
  }

  Future<List<OxigenacaoHistoricoEntrada>> getHistoricoOxigenacao({
    required String idosoId,
    DateTime? dataReferencia,
    String periodo = 'dia',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.oxigenacaoHistorico,
        queryParameters: {
          'idosoId': idosoId,
          'periodo': periodo,
          if (dataReferencia != null)
            'dataReferencia': _toIsoDateOnly(dataReferencia),
        },
      );
      final dados = response.data?['dados'];

      if (dados is List) {
        return dados
            .whereType<Map<String, dynamic>>()
            .map(OxigenacaoHistoricoEntrada.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar histórico de oxigenação.',
      );
    }
  }

  Future<OxigenacaoRegistro> criarOxigenacao({
    required String idosoId,
    required int saturacao,
    required DateTime medidoEm,
    int? pulso,
    String? observacoes,
    String? registradoPorId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.oxigenacao,
        data: {
          'idosoId': idosoId,
          'saturacao': saturacao,
          'medidoEm': medidoEm.toUtc().toIso8601String(),
          if (pulso != null) 'pulso': pulso,
          if (observacoes != null && observacoes.isNotEmpty)
            'observacoes': observacoes,
          if (registradoPorId != null && registradoPorId.isNotEmpty)
            'registradoPorId': registradoPorId,
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return OxigenacaoRegistro.fromJson(dados);
      }

      return OxigenacaoRegistro.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao registrar oxigenação.',
      );
    }
  }

  Future<InsulinaRegistro> criarRegistroInsulina({
    required String idosoId,
    required String tipoInsulina,
    required double doseUnidades,
    required DateTime aplicadoEm,
    String? glicemiaId,
    String? nomeInsulina,
    String? localAplicacao,
    String? observacoes,
    String? registradoPorId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.glicemiaInsulinas,
        data: {
          'idosoId': idosoId,
          if (glicemiaId != null && glicemiaId.isNotEmpty)
            'glicemiaId': glicemiaId,
          if (nomeInsulina != null && nomeInsulina.isNotEmpty)
            'nomeInsulina': nomeInsulina,
          'tipoInsulina': tipoInsulina,
          'doseUnidades': doseUnidades,
          'aplicadoEm': aplicadoEm.toUtc().toIso8601String(),
          if (localAplicacao != null && localAplicacao.isNotEmpty)
            'localAplicacao': localAplicacao,
          if (observacoes != null && observacoes.isNotEmpty)
            'observacoes': observacoes,
          if (registradoPorId != null && registradoPorId.isNotEmpty)
            'registradoPorId': registradoPorId,
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return InsulinaRegistro.fromJson(dados);
      }

      return InsulinaRegistro.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao registrar uso de insulina.',
      );
    }
  }

  Future<MedicamentosResumo> getResumoMedicamentos({
    required String idosoId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.medicamentosResumo,
        queryParameters: {'idosoId': idosoId},
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return MedicamentosResumo.fromJson(dados);
      }

      return MedicamentosResumo.fromJson(const <String, dynamic>{});
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao consultar medicamentos.');
    }
  }

  Future<List<HistoricoMedicamentoEntrada>> getHistoricoMedicamentos({
    required String idosoId,
    DateTime? dataReferencia,
    String periodo = 'dia',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.medicamentosHistorico,
        queryParameters: {
          'idosoId': idosoId,
          'periodo': periodo,
          if (dataReferencia != null)
            'dataReferencia': _toIsoDateOnly(dataReferencia),
        },
      );
      final dados = response.data?['dados'];

      if (dados is List) {
        return dados
            .whereType<Map<String, dynamic>>()
            .map(HistoricoMedicamentoEntrada.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar histórico de medicamentos.',
      );
    }
  }

  Future<List<MedicamentoHorario>> getHorariosMedicamento(
    String medicamentoId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.horariosMedicamento(medicamentoId),
      );
      final dados = response.data?['dados'];

      if (dados is List) {
        return dados
            .whereType<Map<String, dynamic>>()
            .map(MedicamentoHorario.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao consultar horários.');
    }
  }

  Future<List<Map<String, dynamic>>> getAdministracoesMedicamento(
    String medicamentoId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.administracoesMedicamento(medicamentoId),
      );
      final dados = response.data?['dados'];

      if (dados is List) {
        return dados.whereType<Map<String, dynamic>>().toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(
        error,
        fallback: 'Erro ao consultar administrações.',
      );
    }
  }

  Future<MedicamentoDetalhe> criarMedicamento({
    required String idosoId,
    required String nome,
    String? dosagem,
    String? formato,
    String? instrucoes,
    String? dataInicio,
    String? dataFim,
    double? quantidadeEstoque,
    String? unidadeEstoque,
    double? alertaEstoqueBaixo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.medicamentos,
        data: {
          'idosoId': idosoId,
          'nome': nome,
          if (dosagem != null && dosagem.isNotEmpty) 'dosagem': dosagem,
          if (formato != null && formato.isNotEmpty) 'formato': formato,
          if (instrucoes != null && instrucoes.isNotEmpty)
            'instrucoes': instrucoes,
          if (dataInicio != null && dataInicio.isNotEmpty)
            'dataInicio': dataInicio,
          if (dataFim != null && dataFim.isNotEmpty) 'dataFim': dataFim,
          if (quantidadeEstoque != null) 'quantidadeEstoque': quantidadeEstoque,
          if (unidadeEstoque != null && unidadeEstoque.isNotEmpty)
            'unidadeEstoque': unidadeEstoque,
          if (alertaEstoqueBaixo != null)
            'alertaEstoqueBaixo': alertaEstoqueBaixo,
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return MedicamentoDetalhe.fromJson(dados);
      }

      throw const ApiException('Erro ao registrar medicamento.');
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao registrar medicamento.');
    }
  }

  Future<MedicamentoDetalhe> atualizarMedicamento({
    required String id,
    String? nome,
    String? dosagem,
    String? formato,
    String? instrucoes,
    String? dataInicio,
    String? dataFim,
    double? quantidadeEstoque,
    String? unidadeEstoque,
    double? alertaEstoqueBaixo,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.medicamento(id),
        data: {
          if (nome != null && nome.isNotEmpty) 'nome': nome,
          if (dosagem != null && dosagem.isNotEmpty) 'dosagem': dosagem,
          if (formato != null && formato.isNotEmpty) 'formato': formato,
          if (instrucoes != null && instrucoes.isNotEmpty)
            'instrucoes': instrucoes,
          if (dataInicio != null && dataInicio.isNotEmpty)
            'dataInicio': dataInicio,
          if (dataFim != null && dataFim.isNotEmpty) 'dataFim': dataFim,
          if (quantidadeEstoque != null) 'quantidadeEstoque': quantidadeEstoque,
          if (unidadeEstoque != null && unidadeEstoque.isNotEmpty)
            'unidadeEstoque': unidadeEstoque,
          if (alertaEstoqueBaixo != null)
            'alertaEstoqueBaixo': alertaEstoqueBaixo,
        },
      );
      final dados = response.data?['dados'];

      if (dados is Map<String, dynamic>) {
        return MedicamentoDetalhe.fromJson(dados);
      }

      throw const ApiException('Erro ao atualizar medicamento.');
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar medicamento.');
    }
  }

  Future<void> removerMedicamento(String id) async {
    try {
      await _dio.delete<void>(ApiEndpoints.medicamento(id));
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao remover medicamento.');
    }
  }

  Future<List<MedicamentoHorario>> substituirHorariosMedicamento({
    required String medicamentoId,
    required List<
            ({String horario, double? quantidadeDose, String? unidadeDose})>
        horarios,
    String frequenciaTipo = 'diaria',
    List<String>? diasSemana,
    String? registradoPorId,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiEndpoints.horariosMedicamento(medicamentoId),
        data: {
          'frequenciaTipo': frequenciaTipo,
          if (diasSemana != null && diasSemana.isNotEmpty)
            'diasSemana': diasSemana,
          'horarios': [
            for (final item in horarios)
              {
                'horario': item.horario,
                if (item.quantidadeDose != null)
                  'quantidadeDose': item.quantidadeDose,
                if (item.unidadeDose != null && item.unidadeDose!.isNotEmpty)
                  'unidadeDose': item.unidadeDose,
              },
          ],
          if (registradoPorId != null && registradoPorId.isNotEmpty)
            'registradoPorId': registradoPorId,
        },
      );
      final dados = response.data?['dados'];

      if (dados is List) {
        return dados
            .whereType<Map<String, dynamic>>()
            .map(MedicamentoHorario.fromJson)
            .toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao salvar horários.');
    }
  }

  Future<void> registrarAdministracaoMedicamento({
    required String medicamentoId,
    required String idosoId,
    required DateTime horarioPrevisto,
    required String status,
    DateTime? administradoEm,
    double? quantidadeDose,
    String? registradoPorId,
    String? observacoes,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.administracoesMedicamento(medicamentoId),
        data: {
          'idosoId': idosoId,
          'horarioPrevisto': horarioPrevisto.toUtc().toIso8601String(),
          'status': status,
          if (administradoEm != null)
            'administradoEm': administradoEm.toUtc().toIso8601String(),
          if (quantidadeDose != null) 'quantidadeDose': quantidadeDose,
          if (registradoPorId != null && registradoPorId.isNotEmpty)
            'registradoPorId': registradoPorId,
          if (observacoes != null && observacoes.isNotEmpty)
            'observacoes': observacoes,
        },
      );
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao registrar dose.');
    }
  }

  ApiException _toApiException(
    DioException error, {
    required String fallback,
  }) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final mensagem = data['mensagem'];
      if (mensagem is String && mensagem.isNotEmpty) {
        return ApiException(
          mensagem,
          statusCode: error.response?.statusCode,
        );
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return ApiException(
        'Nao foi possivel conectar ao servidor. Verifique se a API esta aberta e tente novamente.',
        statusCode: error.response?.statusCode,
      );
    }

    return ApiException(
      fallback,
      statusCode: error.response?.statusCode,
    );
  }
}

String _toIsoDateOnly(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

double? _numOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _dateOnlyOrNull(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text.length > 10 ? text.substring(0, 10) : text);
}

Map<String, dynamic> _mapOrEmpty(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, data) => MapEntry(key.toString(), data));
  }
  return const <String, dynamic>{};
}
