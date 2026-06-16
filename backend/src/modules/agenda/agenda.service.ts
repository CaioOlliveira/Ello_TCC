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
  AtualizarEventoInput,
  CriarEventoInput,
} from "./agenda.schemas.js";

const table = "eventos_calendario";
const notFound = ["EVENTO_NAO_ENCONTRADO", "Evento não encontrado."] as const;

const fields = {
  idosoId: "idoso_id",
  titulo: "titulo",
  tipoEvento: "tipo_evento",
  inicioEm: "inicio_em",
  fimEm: "fim_em",
  local: "local",
  responsavelId: "responsavel_id",
  repeticao: "repeticao",
  lembreteMinutos: "lembrete_minutos",
  status: "status",
  observacoes: "observacoes",
  criadoPorId: "criado_por_id",
} as const;

export const agendaService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "inicio_em asc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarEventoInput) {
    const criadoPorId = await resolverUsuarioRegistroId(input.criadoPorId);
    const evento = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      table,
      { ...input, criadoPorId, status: input.status ?? "agendado" },
      fields,
    );

    await registrarHistorico({
      usuarioId: criadoPorId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(evento.id),
      dadosNovos: evento,
    });

    return evento;
  },

  async atualizar(id: string, input: AtualizarEventoInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarEventoInput,
      Record<string, unknown>
    >(table, id, input, fields, ...notFound);
    await registrarHistorico({
      usuarioId: input.criadoPorId,
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
