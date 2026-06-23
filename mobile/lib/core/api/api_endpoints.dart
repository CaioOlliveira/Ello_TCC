class ApiEndpoints {
  const ApiEndpoints._();

  static const health = '/health';
  static const login = '/auth/login';
  static const cadastro = '/auth/cadastro';
  static const idosos = '/idosos';
  static const humores = '/registros/humores';
  static const agenda = '/agenda';
  static const equipamentos = '/equipamentos';
  static String compromisso(String id) => '/agenda/$id';
  static String equipamento(String id) => '/equipamentos/$id';
  static String manutencoesEquipamento(String id) =>
      '/equipamentos/$id/manutencoes';
  static String idoso(String id) => '/idosos/$id';
  static String usuario(String id) => '/usuarios/$id';
}
