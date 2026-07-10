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
      medidoEm: DateTime.tryParse(json['medidoEm']?.toString() ?? '') ??
          DateTime.now(),
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
    this.observacoes,
  });

  factory InsulinaRegistro.fromJson(Map<String, dynamic> json) {
    return InsulinaRegistro(
      id: json['id']?.toString() ?? '',
      idosoId: json['idosoId']?.toString() ?? '',
      glicemiaId: json['glicemiaId']?.toString(),
      tipoInsulina: json['tipoInsulina']?.toString() ?? '',
      doseUnidades: json['doseUnidades'] is num
          ? (json['doseUnidades'] as num).toDouble()
          : double.tryParse(json['doseUnidades']?.toString() ?? '') ?? 0,
      aplicadoEm: DateTime.tryParse(json['aplicadoEm']?.toString() ?? '') ??
          DateTime.now(),
      observacoes: json['observacoes']?.toString(),
    );
  }

  final String id;
  final String idosoId;
  final String? glicemiaId;
  final String tipoInsulina;
  final double doseUnidades;
  final DateTime aplicadoEm;
  final String? observacoes;
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
      proximaMedicao:
          proximaMedicao == null ? null : DateTime.tryParse(proximaMedicao),
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

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  final Dio _dio;

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

  Future<List<Map<String, dynamic>>> listarCompromissos({
    String? idosoId,
  }) async {
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
        return data.whereType<Map<String, dynamic>>().toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar compromissos.');
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
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao excluir compromisso.');
    }
  }

  Future<List<Map<String, dynamic>>> listarEquipamentos({
    String? idosoId,
  }) async {
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
        return data.whereType<Map<String, dynamic>>().toList();
      }

      return const [];
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao listar equipamentos.');
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
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error, fallback: 'Erro ao atualizar equipamento.');
    }
  }

  Future<List<Map<String, dynamic>>> listarManutencoesEquipamento({
    required String id,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.manutencoesEquipamento(id),
      );
      final data = response.data?['dados'];

      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
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

  Future<InsulinaRegistro> criarRegistroInsulina({
    required String idosoId,
    required String tipoInsulina,
    required double doseUnidades,
    required DateTime aplicadoEm,
    String? glicemiaId,
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
          'tipoInsulina': tipoInsulina,
          'doseUnidades': doseUnidades,
          'aplicadoEm': aplicadoEm.toUtc().toIso8601String(),
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
