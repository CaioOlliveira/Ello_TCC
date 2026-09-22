import { randomUUID } from "node:crypto";

import { AppError } from "../../common/errors/app-error.js";
import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import type { CriarGastoInput, ListarGastosQuery } from "./gastos.schemas.js";

type GastoRow = {
  id: string;
  idoso_id: string;
  valor: string | number;
  descricao: string;
  fonte: string;
  data_gasto: string | Date;
  criado_por_id: string;
  criado_em: string | Date;
  usuario_nome?: string | null;
};

type Gasto = {
  id: string;
  idosoId: string;
  valor: number;
  descricao: string;
  fonte: string;
  dataGasto: string;
  criadoPorId: string;
  criadoPorNome?: string | null;
  criadoEm: string;
};

const gastosMemoria: Gasto[] = [];
let schemaReady = false;

const toIsoDate = (value: string | Date) => {
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return value.slice(0, 10);
};

const toIsoDateTime = (value: string | Date) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const mapearGasto = (row: GastoRow): Gasto => ({
  id: row.id,
  idosoId: row.idoso_id,
  valor: Number(row.valor),
  descricao: row.descricao,
  fonte: row.fonte,
  dataGasto: toIsoDate(row.data_gasto),
  criadoPorId: row.criado_por_id,
  criadoPorNome: row.usuario_nome ?? null,
  criadoEm: toIsoDateTime(row.criado_em),
});

async function ensureSchema() {
  if (!isDatabaseEnabled || schemaReady) return;

  await getPool().query(`
    create table if not exists gastos_ficha (
      id uuid primary key default gen_random_uuid(),
      idoso_id uuid not null references fichas_idosos(id) on delete cascade,
      valor numeric(12, 2) not null check (valor > 0),
      descricao text not null,
      fonte text not null,
      data_gasto date not null default current_date,
      criado_por_id uuid not null references usuarios(id) on delete restrict,
      criado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    create index if not exists idx_gastos_ficha_periodo
      on gastos_ficha (idoso_id, data_gasto desc, criado_em desc)
  `);

  schemaReady = true;
}

async function validarResponsavelFicha(idosoId: string, usuarioId: string) {
  if (!isDatabaseEnabled) return;

  const result = await getPool().query<{ permitido: boolean }>(
    `
      select coalesce(
        (
          select h.usuario_id
          from historico_alteracoes h
          where h.tipo_entidade = 'fichas_idosos'
            and h.acao = 'criar'
            and h.entidade_id::text = f.id::text
            and h.usuario_id is not null
          order by h.criado_em asc
          limit 1
        ),
        f.criado_por_id
      ) = $2::uuid as permitido
      from fichas_idosos f
      where f.id = $1::uuid
        and f.ativo = true
      limit 1
    `,
    [idosoId, usuarioId],
  );

  if (!result.rows[0]?.permitido) {
    throw new AppError(
      "GASTOS_APENAS_RESPONSAVEL",
      "Apenas o responsavel pela ficha pode acessar os gastos.",
      403,
    );
  }
}

function rangePadrao(input: ListarGastosQuery) {
  const hoje = new Date();
  const fim =
    input.fim ??
    `${hoje.getFullYear().toString().padStart(4, "0")}-${(hoje.getMonth() + 1)
      .toString()
      .padStart(2, "0")}-${hoje.getDate().toString().padStart(2, "0")}`;
  const inicio =
    input.inicio ??
    `${hoje.getFullYear().toString().padStart(4, "0")}-${(hoje.getMonth() + 1)
      .toString()
      .padStart(2, "0")}-01`;

  return { inicio, fim };
}

export const gastosService = {
  async listar(input: ListarGastosQuery & { usuarioId: string }) {
    const { inicio, fim } = rangePadrao(input);

    if (!isDatabaseEnabled) {
      const dados = gastosMemoria
        .filter(
          (gasto) =>
            gasto.idosoId === input.idosoId &&
            gasto.dataGasto >= inicio &&
            gasto.dataGasto <= fim,
        )
        .sort((a, b) => b.dataGasto.localeCompare(a.dataGasto));
      const total = dados.reduce((sum, gasto) => sum + gasto.valor, 0);
      return { dados, resumo: { total, inicio, fim } };
    }

    await ensureSchema();
    await validarResponsavelFicha(input.idosoId, input.usuarioId);

    const result = await getPool().query<GastoRow>(
      `
        select
          g.*,
          u.nome as usuario_nome
        from gastos_ficha g
        left join usuarios u on u.id = g.criado_por_id
        where g.idoso_id = $1
          and g.data_gasto between $2::date and $3::date
        order by g.data_gasto desc, g.criado_em desc
      `,
      [input.idosoId, inicio, fim],
    );

    const dados = result.rows.map(mapearGasto);
    const total = dados.reduce((sum, gasto) => sum + gasto.valor, 0);

    return { dados, resumo: { total, inicio, fim } };
  },

  async criar(input: CriarGastoInput & { usuarioId: string }) {
    if (!isDatabaseEnabled) {
      const gasto: Gasto = {
        id: randomUUID(),
        idosoId: input.idosoId,
        valor: input.valor,
        descricao: input.descricao,
        fonte: input.fonte,
        dataGasto: input.dataGasto,
        criadoPorId: input.usuarioId,
        criadoEm: new Date().toISOString(),
      };
      gastosMemoria.unshift(gasto);
      return gasto;
    }

    await ensureSchema();
    await validarResponsavelFicha(input.idosoId, input.usuarioId);

    const result = await getPool().query<GastoRow>(
      `
        insert into gastos_ficha (
          idoso_id,
          valor,
          descricao,
          fonte,
          data_gasto,
          criado_por_id
        )
        values ($1, $2, $3, $4, $5::date, $6)
        returning *
      `,
      [
        input.idosoId,
        input.valor,
        input.descricao,
        input.fonte,
        input.dataGasto,
        input.usuarioId,
      ],
    );

    const gasto = mapearGasto(result.rows[0]);
    await registrarHistorico({
      usuarioId: input.usuarioId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: "gastos_ficha",
      entidadeId: gasto.id,
      dadosNovos: gasto,
    });

    return gasto;
  },
};
