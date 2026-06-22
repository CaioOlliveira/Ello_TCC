import { registrarHistorico } from "../../database/audit.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import { notificacoesService } from "../notificacoes/notificacoes.service.js";
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

const table = "tarefas";
const notFound = ["TAREFA_NAO_ENCONTRADA", "Tarefa nao encontrada."] as const;

const fields = {
  idosoId: "idoso_id",
  titulo: "titulo",
  tags: "tags",
  dataCompromisso: "data_compromisso",
  horaCompromisso: "hora_compromisso",
  local: "local",
  atribuidoParaId: "atribuido_para_id",
  responsavelId: "responsavel_id",
  frequencia: "frequencia",
  observacoes: "observacoes",
  ativarLembrete: "ativar_lembrete",
  antecedenciaLembreteMinutos: "antecedencia_lembrete_minutos",
  status: "status",
  criadoPorId: "criado_por_id",
} as const;

export const agendaService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy:
        "data_compromisso asc nulls last, hora_compromisso asc nulls last",
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
      {
        ...input,
        criadoPorId,
        atribuidoParaId: input.atribuidoParaId ?? criadoPorId,
        status: input.status ?? "agendado",
      },
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

    if (
      input.ativarLembrete &&
      input.antecedenciaLembreteMinutos !== undefined
    ) {
      const programadoPara = new Date(
        `${input.dataCompromisso}T${input.horaCompromisso}`,
      );
      programadoPara.setMinutes(
        programadoPara.getMinutes() - input.antecedenciaLembreteMinutos,
      );

      await notificacoesService.criar({
        idosoId: input.idosoId,
        usuarioId: criadoPorId,
        titulo: `Lembrete: ${input.titulo}`,
        mensagem: `O compromisso "${input.titulo}" esta chegando.`,
        tipoNotificacao: "agenda",
        tipoEntidadeRelacionada: table,
        entidadeRelacionadaId: String(evento.id),
        programadoPara: programadoPara.toISOString(),
      });
    }

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
