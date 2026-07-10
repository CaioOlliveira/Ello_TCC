class ApiEndpoints {
  const ApiEndpoints._();

  static const health = '/health';
  static const login = '/auth/login';
  static const cadastro = '/auth/cadastro';
  static const idosos = '/idosos';
  static const humores = '/registros/humores';
  static const hidratacoes = '/registros/hidratacoes';
  static const agenda = '/agenda';
  static const equipamentos = '/equipamentos';
  static const insumos = '/insumos';
  static const refeicoes = '/refeicoes';
  static const dicaAlimentacao = '/refeicoes/dica';
  static const glicemias = '/glicemias';
  static const glicemiaResumo = '/glicemias/resumo';
  static const glicemiaInsulinas = '/glicemias/insulinas';
  static String compromisso(String id) => '/agenda/$id';
  static String equipamento(String id) => '/equipamentos/$id';
  static String insumo(String id) => '/insumos/$id';
  static String refeicao(String id) => '/refeicoes/$id';
  static String concluirRefeicao(String id) => '/refeicoes/$id/concluir';
  static String movimentacoesInsumo(String id) => '/insumos/$id/movimentacoes';
  static String manutencoesEquipamento(String id) =>
      '/equipamentos/$id/manutencoes';
  static String idoso(String id) => '/idosos/$id';
  static String usuario(String id) => '/usuarios/$id';
}
