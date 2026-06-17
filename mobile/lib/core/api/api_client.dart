import 'package:dio/dio.dart';

import 'api_endpoints.dart';
import 'api_exception.dart';

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

  Future<Map<String, dynamic>> criarIdoso({
    required String nomeCompleto,
    String? dataNascimento,
    String? urlFoto,
    String? sexo,
    List<String>? condicoesSaude,
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
          if (sexo != null && sexo.isNotEmpty) 'sexo': sexo,
          if (condicoesSaude != null && condicoesSaude.isNotEmpty)
            'condicoesSaude': condicoesSaude,
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

    return ApiException(
      error.message ?? fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
