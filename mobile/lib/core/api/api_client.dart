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
    this.monitoramentos = const [],
  });

  factory IdosoResumo.fromJson(Map<String, dynamic> json) {
    final condicoes = json['condicoes'];
    final monitoramentos = json['monitoramentos'];

    return IdosoResumo(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? 'Sem nome',
      idade: json['idade'] is num ? (json['idade'] as num).toInt() : 0,
      urlFoto: json['urlFoto']?.toString(),
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
  final List<String> condicoes;
  final List<String> monitoramentos;

  IdosoResumo copyWith({
    String? nome,
    int? idade,
    String? urlFoto,
    List<String>? condicoes,
    List<String>? monitoramentos,
  }) {
    return IdosoResumo(
      id: id,
      nome: nome ?? this.nome,
      idade: idade ?? this.idade,
      urlFoto: urlFoto ?? this.urlFoto,
      condicoes: condicoes ?? this.condicoes,
      monitoramentos: monitoramentos ?? this.monitoramentos,
    );
  }
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
    List<String>? condicoesSaude,
    List<String>? monitoramentos,
    String? alergiasRestricoes,
    String? observacoesGerais,
    String? contatoEmergenciaNome,
    String? contatoEmergenciaTelefone,
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
          if (condicoesSaude != null && condicoesSaude.isNotEmpty)
            'condicoesSaude': condicoesSaude,
          if (monitoramentos != null && monitoramentos.isNotEmpty)
            'monitoramentos': monitoramentos,
          if (alergiasRestricoes != null && alergiasRestricoes.isNotEmpty)
            'alergiasRestricoes': alergiasRestricoes,
          if (observacoesGerais != null && observacoesGerais.isNotEmpty)
            'observacoesGerais': observacoesGerais,
          if ((contatoEmergenciaNome != null &&
                  contatoEmergenciaNome.isNotEmpty) ||
              (contatoEmergenciaTelefone != null &&
                  contatoEmergenciaTelefone.isNotEmpty))
            'contatoEmergencia': {
              'nome': contatoEmergenciaNome,
              'telefone': contatoEmergenciaTelefone,
              'principal': true,
            },
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
