import { AppError } from "../../common/errors/app-error.js";
import { registrarHistorico } from "../../database/audit.js";
import { getPool } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import { notificacoesService } from "../notificacoes/notificacoes.service.js";
import {
  deleteRow,
  insertRow,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarEventoInput,
  AtualizarOcorrenciaEventoInput,
  CriarEventoInput,
} from "./agenda.schemas.js";

const table = "tarefas";
const occurrencesTable = "tarefas_ocorrencias_status";
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
  async garantirTabelaOcorrencias() {
    await getPool().query(`
      create table if not exists ${occurrencesTable} (
        tarefa_id uuid not null references ${table}(id) on delete cascade,
        data_ocorrencia date not null,
        status text not null,
        criado_em timestamptz not null default now(),
        atualizado_em timestamptz not null default now(),
        primary key (tarefa_id, data_ocorrencia)
      )
    `);
  },

  async listar(limit: number, offset: number, idosoId?: string) {
    await this.garantirTabelaOcorrencias();
    const where = idosoId ? "where t.idoso_id = $1" : "";
    const params = idosoId ? [idosoId] : [];

    const countResult = await getPool().query<{ total: string }>(
      `select count(*) as total from ${table} t ${where}`,
      params,
    );

    const result = await getPool().query<Record<string, unknown>>(
      `
        select
          t.*,
          u.nome as criado_por_nome,
          coalesce(
            json_agg(
              json_build_object(
                'data_ocorrencia', tos.data_ocorrencia,
                'status', tos.status
              )
              order by tos.data_ocorrencia
            ) filter (where tos.tarefa_id is not null),
            '[]'::json
          ) as ocorrencias_status
        from ${table} t
        left join usuarios u on u.id = t.criado_por_id
        left join ${occurrencesTable} tos on tos.tarefa_id = t.id
        ${where}
        group by t.id, u.nome
        order by t.data_compromisso asc nulls last, t.hora_compromisso asc nulls last
        limit $${params.length + 1} offset $${params.length + 2}
      `,
      [...params, limit, offset],
    );

    return {
      dados: result.rows,
      total: Number(countResult.rows[0]?.total ?? 0),
    };
  },

  async buscarPorId(id: string) {
    await this.garantirTabelaOcorrencias();
    const result = await getPool().query<Record<string, unknown>>(
      `
        select
          t.*,
          u.nome as criado_por_nome,
          coalesce(
            json_agg(
              json_build_object(
                'data_ocorrencia', tos.data_ocorrencia,
                'status', tos.status
              )
              order by tos.data_ocorrencia
            ) filter (where tos.tarefa_id is not null),
            '[]'::json
          ) as ocorrencias_status
        from ${table} t
        left join usuarios u on u.id = t.criado_por_id
        left join ${occurrencesTable} tos on tos.tarefa_id = t.id
        where t.id = $1
        group by t.id, u.nome
        limit 1
      `,
      [id],
    );

    const row = result.rows[0];
    if (!row) {
      throw new AppError(notFound[0], notFound[1], 404);
    }

    return row;
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

    return this.buscarPorId(String(evento.id));
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
    return this.buscarPorId(String(atualizado.id));
  },

  async atualizarOcorrencia(
    id: string,
    input: AtualizarOcorrenciaEventoInput,
  ) {
    await this.buscarPorId(id);
    await this.garantirTabelaOcorrencias();

    if (input.status === "agendado") {
      await getPool().query(
        `delete from ${occurrencesTable} where tarefa_id = $1 and data_ocorrencia = $2`,
        [id, input.dataOcorrencia],
      );
    } else {
      await getPool().query(
        `
          insert into ${occurrencesTable} (
            tarefa_id,
            data_ocorrencia,
            status
          )
          values ($1, $2, $3)
          on conflict (tarefa_id, data_ocorrencia)
          do update set status = excluded.status, atualizado_em = now()
        `,
        [id, input.dataOcorrencia, input.status],
      );
    }

    return this.buscarPorId(id);
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
