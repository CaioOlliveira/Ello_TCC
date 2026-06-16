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
      throw ApiException(
        error.message ?? 'Erro ao consultar a API.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
