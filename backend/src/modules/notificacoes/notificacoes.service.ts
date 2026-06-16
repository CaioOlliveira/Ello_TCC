import {
  deleteRow,
  getRowById,
  insertRow,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarNotificacaoInput,
  CriarNotificacaoInput,
} from "./notificacoes.schemas.js";

const table = "notificacoes";
const notFound = [
  "NOTIFICACAO_NAO_ENCONTRADA",
  "Notificação não encontrada.",
] as const;

const fields = {
  idosoId: "idoso_id",
  usuarioId: "usuario_id",
  titulo: "titulo",
  mensagem: "mensagem",
  tipoNotificacao: "tipo_notificacao",
  tipoEntidadeRelacionada: "tipo_entidade_relacionada",
  entidadeRelacionadaId: "entidade_relacionada_id",
  programadoPara: "programado_para",
  lidoEm: "lido_em",
} as const;

export const notificacoesService = {
  async listar(limit: number, offset: number, usuarioId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: usuarioId ? "usuario_id = $1" : undefined,
      params: usuarioId ? [usuarioId] : undefined,
      orderBy: "coalesce(programado_para, now()) desc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarNotificacaoInput) {
    return insertRow<CriarNotificacaoInput, Record<string, unknown>>(
      table,
      input,
      fields,
    );
  },

  async atualizar(id: string, input: AtualizarNotificacaoInput) {
    return updateRow<AtualizarNotificacaoInput, Record<string, unknown>>(
      table,
      id,
      input,
      fields,
      ...notFound,
    );
  },

  async marcarComoLida(id: string) {
    return updateRow<Record<string, unknown>, Record<string, unknown>>(
      table,
      id,
      { lidoEm: new Date().toISOString() },
      fields,
      ...notFound,
    );
  },

  async remover(id: string) {
    await deleteRow(table, id, ...notFound);
  },
};
