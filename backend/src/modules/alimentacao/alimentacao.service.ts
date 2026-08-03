import { AppError } from "../../common/errors/app-error.js";
import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import { deleteRow, getRowById } from "../../database/simple-crud.js";
import type {
  AtualizarRefeicaoInput,
  CriarRefeicaoInput,
} from "./alimentacao.schemas.js";

const table = "registros_alimentacao";
const notFound = [
  "REFEICAO_NAO_ENCONTRADA",
  "Refeicao nao encontrada.",
] as const;

type RefeicaoRow = Record<string, unknown> & {
  id: string;
  idoso_id?: string;
  tipo_refeicao?: string;
  alimentou_em?: string;
  data_consumo?: string;
  hora_consumo?: string;
  alimentos_consumidos?: unknown;
  aceitacao?: string;
  recordatorio?: string | null;
  observacoes?: string | null;
  registrado_por_id?: string | null;
  concluida_em?: string | null;
};

const toDateTime = (
  data?: string,
  hora?: string,
  fallback?: string,
): string => {
  if (data && hora) return `${data}T${hora}:00.000Z`;
  return fallback ?? new Date().toISOString();
};

const mapearRefeicao = (row: RefeicaoRow) => ({
  id: row.id,
  idosoId: row.idoso_id,
  tipoRefeicao: row.tipo_refeicao,
  registradoEm: row.alimentou_em,
  dataConsumo: row.data_consumo,
  horaConsumo:
    typeof row.hora_consumo === "string"
      ? row.hora_consumo.slice(0, 5)
      : row.hora_consumo,
  alimentos: Array.isArray(row.alimentos_consumidos)
    ? row.alimentos_consumidos
    : [],
  aceitacao: row.aceitacao,
  recordatorio: row.recordatorio,
  observacoes: row.observacoes,
  registradoPorId: row.registrado_por_id,
  concluidaEm: row.concluida_em,
});

export const alimentacaoService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    if (!isDatabaseEnabled) {
      return { dados: [], total: 0 };
    }

    const where = idosoId ? "where idoso_id = $1" : "";
    const params = idosoId ? [idosoId] : [];
    const countResult = await getPool().query<{ total: string }>(
      `select count(*) as total from ${table} ${where}`,
      params,
    );
    const result = await getPool().query<RefeicaoRow>(
      `
        select *
        from ${table}
        ${where}
        order by coalesce(data_consumo, alimentou_em::date) desc,
                 coalesce(hora_consumo, alimentou_em::time) desc
        limit $${params.length + 1}
        offset $${params.length + 2}
      `,
      [...params, limit, offset],
    );

    return {
      dados: result.rows.map(mapearRefeicao),
      total: Number(countResult.rows[0]?.total ?? 0),
    };
  },

  async buscarPorId(id: string) {
    const refeicao = await getRowById<RefeicaoRow>(table, id, ...notFound);
    return mapearRefeicao(refeicao);
  },

  async buscarDica() {
    if (!isDatabaseEnabled) {
      return { texto: "Refeicoes nutritivas fazem toda a diferenca." };
    }

    const result = await getPool().query<{ texto: string }>(
      `
        select texto
        from dicas_alimentacao
        where ativo = true
        order by criado_em desc
        limit 1
      `,
    );

    return {
      texto:
        result.rows[0]?.texto ?? "Refeicoes nutritivas fazem toda a diferenca.",
    };
  },

  async criar(input: CriarRefeicaoInput) {
    if (!isDatabaseEnabled) {
      return { id: "refeicao-1", ...input };
    }

    const registradoPorId = await resolverUsuarioRegistroId(
      input.registradoPorId,
    );
    const alimentouEm = toDateTime(
      input.dataConsumo,
      input.horaConsumo,
      input.registradoEm,
    );

    const result = await getPool().query<RefeicaoRow>(
      `
        insert into registros_alimentacao (
          idoso_id,
          tipo_refeicao,
          alimentou_em,
          data_consumo,
          hora_consumo,
          alimentos_consumidos,
          aceitacao,
          recordatorio,
          observacoes,
          registrado_por_id
        )
        values ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9, $10)
        returning *
      `,
      [
        input.idosoId,
        input.tipoRefeicao,
        alimentouEm,
        input.dataConsumo ?? alimentouEm.slice(0, 10),
        input.horaConsumo ?? alimentouEm.slice(11, 16),
        JSON.stringify(input.alimentos),
        input.aceitacao,
        input.recordatorio ?? null,
        input.observacoes ?? null,
        registradoPorId,
      ],
    );

    const dados = mapearRefeicao(result.rows[0]);
    await registrarHistorico({
      usuarioId: registradoPorId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(dados.id),
      dadosNovos: dados,
    });

    return dados;
  },

  async atualizar(id: string, input: AtualizarRefeicaoInput) {
    const anterior = await getRowById<RefeicaoRow>(table, id, ...notFound);
    const alimentouEm =
      input.dataConsumo || input.horaConsumo
        ? toDateTime(
            input.dataConsumo ?? String(anterior.data_consumo),
            input.horaConsumo ??
              (typeof anterior.hora_consumo === "string"
                ? anterior.hora_consumo.slice(0, 5)
                : undefined),
            String(anterior.alimentou_em),
          )
        : input.registradoEm;

    const result = await getPool().query<RefeicaoRow>(
      `
        update registros_alimentacao
        set
          tipo_refeicao = coalesce($1, tipo_refeicao),
          alimentou_em = coalesce($2, alimentou_em),
          data_consumo = coalesce($3, data_consumo),
          hora_consumo = coalesce($4, hora_consumo),
          alimentos_consumidos = coalesce($5::jsonb, alimentos_consumidos),
          aceitacao = coalesce($6, aceitacao),
          recordatorio = coalesce($7, recordatorio),
          observacoes = $8
        where id = $9
        returning *
      `,
      [
        input.tipoRefeicao,
        alimentouEm,
        input.dataConsumo,
        input.horaConsumo,
        input.alimentos ? JSON.stringify(input.alimentos) : null,
        input.aceitacao,
        input.recordatorio,
        input.observacoes ?? null,
        id,
      ],
    );

    const atualizado = result.rows[0];
    if (!atualizado) throw new AppError(...notFound, 404);

    const dados = mapearRefeicao(atualizado);
    await registrarHistorico({
      usuarioId: input.registradoPorId,
      idosoId: String(atualizado.idoso_id ?? ""),
      acao: "atualizar",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
      dadosNovos: dados,
    });

    return dados;
  },

  async concluir(id: string, usuarioId?: string) {
    const result = await getPool().query<RefeicaoRow>(
      `
        update registros_alimentacao
        set concluida_em = now()
        where id = $1
        returning *
      `,
      [id],
    );
    const atualizado = result.rows[0];
    if (!atualizado) throw new AppError(...notFound, 404);

    const dados = mapearRefeicao(atualizado);
    await registrarHistorico({
      usuarioId,
      idosoId: String(atualizado.idoso_id ?? ""),
      acao: "concluir",
      tipoEntidade: table,
      entidadeId: id,
      dadosNovos: dados,
    });
    return dados;
  },

  async remover(id: string) {
    const anterior = await this.buscarPorId(id);
    await deleteRow(table, id, ...notFound);
    await registrarHistorico({
      idosoId: String(anterior.idosoId ?? ""),
      acao: "remover",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
    });
  },
};
