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
