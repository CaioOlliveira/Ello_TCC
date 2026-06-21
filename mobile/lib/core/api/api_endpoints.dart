class ApiEndpoints {
  const ApiEndpoints._();

  static const health = '/health';
  static const login = '/auth/login';
  static const cadastro = '/auth/cadastro';
  static const idosos = '/idosos';
  static const humores = '/registros/humores';
  static String idoso(String id) => '/idosos/$id';
  static String usuario(String id) => '/usuarios/$id';
}
