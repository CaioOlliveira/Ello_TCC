class ApiEndpoints {
  const ApiEndpoints._();

  static const health = '/health';
  static const login = '/auth/login';
  static const cadastro = '/auth/cadastro';
  static const idosos = '/idosos';
  static const idososAdministrados = '/idosos/administrados';
  static const convites = '/convites';
  static const convitesAceitar = '/convites/aceitar';
  static const membrosParticipantes = '/membros/participantes';
  static const membrosPendentes = '/membros/pendentes';
  static const humores = '/registros/humores';
  static const hidratacoes = '/registros/hidratacoes';
  static const agenda = '/agenda';
  static const agendaHistorico = '/agenda/historico';
  static const equipamentos = '/equipamentos';
  static const equipamentosHistorico = '/equipamentos/historico';
  static const insumos = '/insumos';
  static const refeicoes = '/refeicoes';
  static const dicaAlimentacao = '/refeicoes/dica';
  static const glicemias = '/glicemias';
  static const iaPerguntar = '/ia/perguntar';
  static const iaConversas = '/ia/conversas';
  static const iaRelatorioInicial = '/ia/relatorio-inicial';
  static const glicemiaResumo = '/glicemias/resumo';
  static const glicemiaHistorico = '/glicemias/historico';
  static const glicemiaInsulinas = '/glicemias/insulinas';
  static const medicamentos = '/medicamentos';
  static const medicamentosResumo = '/medicamentos/resumo';
  static const medicamentosHistorico = '/medicamentos/historico';
  static const pressao = '/pressao';
  static const pressaoResumo = '/pressao/resumo';
  static const pressaoHistorico = '/pressao/historico';
  static const oxigenacao = '/oxigenacao';
  static const oxigenacaoResumo = '/oxigenacao/resumo';
  static const oxigenacaoHistorico = '/oxigenacao/historico';
  static String dicaDashboard(String idosoId) =>
      '/dashboard/idosos/$idosoId/dica';
  static String compromisso(String id) => '/agenda/$id';
  static String ocorrenciaCompromisso(String id) => '/agenda/$id/ocorrencias';
  static String equipamento(String id) => '/equipamentos/$id';
  static String insumo(String id) => '/insumos/$id';
  static String refeicao(String id) => '/refeicoes/$id';
  static String concluirRefeicao(String id) => '/refeicoes/$id/concluir';
  static String movimentacoesInsumo(String id) => '/insumos/$id/movimentacoes';
  static String manutencoesEquipamento(String id) =>
      '/equipamentos/$id/manutencoes';
  static String idoso(String id) => '/idosos/$id';
  static String usuario(String id) => '/usuarios/$id';
  static String iaMensagens(String conversaId) =>
      '/ia/conversas/$conversaId/mensagens';
  static String membro(String id) => '/membros/$id';
  static String membroAprovar(String id) => '/membros/$id/aprovar';
  static String membroNegar(String id) => '/membros/$id/negar';
  static String membroRevogar(String id) => '/membros/$id/revogar';
  static String medicamento(String id) => '/medicamentos/$id';
  static String horariosMedicamento(String id) => '/medicamentos/$id/horarios';
  static String administracoesMedicamento(String id) =>
      '/medicamentos/$id/administracoes';
}
