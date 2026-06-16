import { registrarHistorico } from "../../database/audit.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  deleteRow,
  getRowById,
  insertRow,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarEquipamentoInput,
  CriarEquipamentoInput,
  CriarManutencaoInput,
} from "./equipamentos.schemas.js";

const table = "equipamentos";
const notFound = [
  "EQUIPAMENTO_NAO_ENCONTRADO",
  "Equipamento não encontrado.",
] as const;

const fields = {
  idosoId: "idoso_id",
  nome: "nome",
  tipo: "tipo",
  marca: "marca",
  modelo: "modelo",
  numeroSerie: "numero_serie",
  dataAquisicao: "data_aquisicao",
  localGuardado: "local_guardado",
  responsavelId: "responsavel_id",
  urlManual: "url_manual",
  frequenciaManutencaoDias: "frequencia_manutencao_dias",
  proximaManutencaoEm: "proxima_manutencao_em",
  status: "status",
  observacoesSeguranca: "observacoes_seguranca",
} as const;

export const equipamentosService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "nome asc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarEquipamentoInput) {
    const equipamento = await insertRow<
      CriarEquipamentoInput,
      Record<string, unknown>
    >(table, { ...input, status: input.status ?? "em_uso" }, fields);
    await registrarHistorico({
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(equipamento.id),
      dadosNovos: equipamento,
    });
    return equipamento;
  },

  async atualizar(id: string, input: AtualizarEquipamentoInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarEquipamentoInput,
      Record<string, unknown>
    >(table, id, input, fields, ...notFound);
    await registrarHistorico({
      idosoId: String(atualizado.idoso_id ?? ""),
      acao: "atualizar",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
      dadosNovos: atualizado,
    });
    return atualizado;
  },

  async remover(id: string) {
    const anterior = await this.buscarPorId(id);
    await deleteRow(table, id, ...notFound);
    await registrarHistorico({
      idosoId: String(anterior.idoso_id ?? ""),
      acao: "remover",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
    });
  },

  async registrarManutencao(
    equipamentoId: string,
    input: CriarManutencaoInput,
  ) {
    const registradoPorId = await resolverUsuarioRegistroId(
      input.registradoPorId,
    );
    const manutencao = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      "manutencoes_equipamentos",
      { ...input, equipamentoId, registradoPorId },
      {
        equipamentoId: "equipamento_id",
        dataManutencao: "data_manutencao",
        tipoManutencao: "tipo_manutencao",
        descricaoServico: "descricao_servico",
        pecasTrocadas: "pecas_trocadas",
        profissionalEmpresa: "profissional_empresa",
        proximaManutencaoEm: "proxima_manutencao_em",
        custo: "custo",
        observacoes: "observacoes",
        registradoPorId: "registrado_por_id",
      },
    );

    return manutencao;
  },
};
