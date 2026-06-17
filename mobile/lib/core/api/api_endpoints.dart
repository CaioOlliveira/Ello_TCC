class ApiEndpoints {
  const ApiEndpoints._();

  static const health = '/health';
  static const login = '/auth/login';
  static const cadastro = '/auth/cadastro';
  static const idosos = '/idosos';
  static String usuario(String id) => '/usuarios/$id';
}
