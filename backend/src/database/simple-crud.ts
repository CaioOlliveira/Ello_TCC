import { AppError } from "../common/errors/app-error.js";
import { getPool } from "./pool.js";
import type { QueryResultRow } from "pg";

type ListOptions = {
  where?: string;
  params?: unknown[];
  orderBy?: string;
  limit: number;
  offset: number;
};

export type FieldMap<TInput extends Record<string, unknown>> = Partial<
  Record<keyof TInput, string>
>;

export const listRows = async <TRow extends QueryResultRow>(
  table: string,
  options: ListOptions,
): Promise<{ dados: TRow[]; total: number }> => {
  const where = options.where ? `where ${options.where}` : "";
  const orderBy = options.orderBy ?? "criado_em desc";
  const params = options.params ?? [];

  const countResult = await getPool().query<{ total: string }>(
    `select count(*) as total from ${table} ${where}`,
    params,
  );

  const result = await getPool().query<TRow>(
    `select * from ${table} ${where} order by ${orderBy} limit $${params.length + 1} offset $${params.length + 2}`,
    [...params, options.limit, options.offset],
  );

  return {
    dados: result.rows,
    total: Number(countResult.rows[0]?.total ?? 0),
  };
};

export const getRowById = async <TRow extends QueryResultRow>(
  table: string,
  id: string,
  codigoErro: string,
  mensagemErro: string,
): Promise<TRow> => {
  const result = await getPool().query<TRow>(
    `select * from ${table} where id = $1 limit 1`,
    [id],
  );

  const row = result.rows[0];

  if (!row) {
    throw new AppError(codigoErro, mensagemErro, 404);
  }

  return row;
};

export const insertRow = async <
  TInput extends Record<string, unknown>,
  TRow extends QueryResultRow,
>(
  table: string,
  input: TInput,
  fields: FieldMap<TInput>,
): Promise<TRow> => {
  const entries = Object.entries(fields)
    .map(([key, column]) => ({
      key,
      column,
      value: input[key],
    }))
    .filter((entry) => entry.value !== undefined);

  const columns = entries.map((entry) => entry.column).join(", ");
  const placeholders = entries.map((_, index) => `$${index + 1}`).join(", ");
  const values = entries.map((entry) => entry.value);

  const result = await getPool().query<TRow>(
    `insert into ${table} (${columns}) values (${placeholders}) returning *`,
    values,
  );

  return result.rows[0];
};

export const updateRow = async <
  TInput extends Record<string, unknown>,
  TRow extends QueryResultRow,
>(
  table: string,
  id: string,
  input: TInput,
  fields: FieldMap<TInput>,
  codigoErro: string,
  mensagemErro: string,
): Promise<TRow> => {
  const entries = Object.entries(fields)
    .map(([key, column]) => ({
      key,
      column,
      value: input[key],
    }))
    .filter((entry) => entry.value !== undefined);

  if (entries.length === 0) {
    return getRowById<TRow>(table, id, codigoErro, mensagemErro);
  }

  const sets = entries
    .map((entry, index) => `${entry.column} = $${index + 1}`)
    .join(", ");
  const values = entries.map((entry) => entry.value);

  const result = await getPool().query<TRow>(
    `update ${table} set ${sets} where id = $${entries.length + 1} returning *`,
    [...values, id],
  );

  const row = result.rows[0];

  if (!row) {
    throw new AppError(codigoErro, mensagemErro, 404);
  }

  return row;
};

export const deleteRow = async (
  table: string,
  id: string,
  codigoErro: string,
  mensagemErro: string,
): Promise<void> => {
  const result = await getPool().query(`delete from ${table} where id = $1`, [
    id,
  ]);

  if (result.rowCount === 0) {
    throw new AppError(codigoErro, mensagemErro, 404);
  }
};
