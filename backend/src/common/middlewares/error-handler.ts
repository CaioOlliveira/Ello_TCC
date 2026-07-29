import type { ErrorRequestHandler } from "express";
import { ZodError } from "zod";

import { AppError } from "../errors/app-error.js";

const isDatabaseConnectionError = (
  error: unknown,
): error is { code?: string; message?: string } =>
  Boolean(
    error &&
    typeof error === "object" &&
    "code" in error &&
    typeof (error as { code?: unknown }).code === "string",
  );

export const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof ZodError) {
    const campos = Object.fromEntries(
      error.issues.map((issue) => [issue.path.join("."), issue.message]),
    );

    return res.status(400).json({
      codigo: "DADOS_INVALIDOS",
      mensagem: "Existem informações inválidas.",
      campos,
    });
  }

  if (error instanceof AppError) {
    return res.status(error.statusCode).json({
      codigo: error.codigo,
      mensagem: error.mensagem,
    });
  }

  if (isDatabaseConnectionError(error)) {
    const errorCode = error.code;

    if (errorCode === "28P01") {
      return res.status(503).json({
        codigo: "BANCO_AUTENTICACAO_INVALIDA",
        mensagem:
          "Falha ao autenticar no banco de dados. Revise usuario, senha e encode da DATABASE_URL no .env.",
      });
    }

    if (
      errorCode &&
      ["ETIMEDOUT", "ETIMEOUT", "ECONNREFUSED", "ENOTFOUND"].includes(errorCode)
    ) {
      return res.status(503).json({
        codigo: "BANCO_INDISPONIVEL",
        mensagem:
          "Nao foi possivel conectar ao banco de dados. Verifique a DATABASE_URL, a rede e se o Supabase esta ativo.",
      });
    }
  }

  console.error("Erro nao tratado na API:", error);

  return res.status(500).json({
    codigo: "ERRO_INTERNO",
    mensagem: "Ocorreu um erro inesperado.",
  });
};
