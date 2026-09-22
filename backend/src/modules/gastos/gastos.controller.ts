import type { RequestHandler } from "express";

import { getAuthenticatedUserId } from "../../common/middlewares/authenticated-user.js";
import { asyncHandler } from "../../common/utils/async-handler.js";
import { criarGastoSchema, listarGastosQuerySchema } from "./gastos.schemas.js";
import { gastosService } from "./gastos.service.js";

export const listarGastos: RequestHandler = asyncHandler(async (req, res) => {
  const input = listarGastosQuerySchema.parse(req.query);
  res.json({
    dados: await gastosService.listar({
      ...input,
      usuarioId: getAuthenticatedUserId(req),
    }),
  });
});

export const criarGasto: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarGastoSchema.parse(req.body);
  res.status(201).json({
    dados: await gastosService.criar({
      ...input,
      usuarioId: getAuthenticatedUserId(req),
    }),
  });
});
