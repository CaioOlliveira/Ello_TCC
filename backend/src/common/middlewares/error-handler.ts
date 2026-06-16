import type { ErrorRequestHandler } from "express";
import { ZodError } from "zod";

import { AppError } from "../errors/app-error.js";

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

  return res.status(500).json({
    codigo: "ERRO_INTERNO",
    mensagem: "Ocorreu um erro inesperado.",
  });
};
