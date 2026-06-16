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
  AtualizarRelatorioInput,
  CriarRelatorioInput,
} from "./relatorios.schemas.js";

const table = "relatorios";
const notFound = [
  "RELATORIO_NAO_ENCONTRADO",
  "Relatório não encontrado.",
] as const;

const fields = {
  idosoId: "idoso_id",
  tipoRelatorio: "tipo_relatorio",
  periodoInicio: "periodo_inicio",
  periodoFim: "periodo_fim",
  resumoTexto: "resumo_texto",
  urlArquivo: "url_arquivo",
  geradoPorId: "gerado_por_id",
} as const;

export const relatoriosService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "criado_em desc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarRelatorioInput) {
    const geradoPorId = await resolverUsuarioRegistroId(input.geradoPorId);
    const relatorio = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(table, { ...input, geradoPorId }, fields);
    await registrarHistorico({
      usuarioId: geradoPorId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(relatorio.id),
      dadosNovos: relatorio,
    });
    return relatorio;
  },

  async atualizar(id: string, input: AtualizarRelatorioInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarRelatorioInput,
      Record<string, unknown>
    >(table, id, input, fields, ...notFound);
    await registrarHistorico({
      usuarioId: input.geradoPorId,
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
};
