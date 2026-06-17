import pg from "pg";

import { AppError } from "../common/errors/app-error.js";
import { env } from "../config/env.js";

export const isDatabaseEnabled = Boolean(env.DATABASE_URL);

const pool = env.DATABASE_URL
  ? new pg.Pool({
      connectionString: env.DATABASE_URL,
      connectionTimeoutMillis: 5000,
      query_timeout: 10000,
      ssl: {
        rejectUnauthorized: false,
      },
    })
  : null;

export const getPool = (): pg.Pool => {
  if (!pool) {
    throw new AppError(
      "BANCO_NAO_CONFIGURADO",
      "Banco de dados não configurado. Informe DATABASE_URL no .env.",
      503,
    );
  }

  return pool;
};
