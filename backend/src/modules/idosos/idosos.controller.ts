import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import { idParamSchema } from "../../common/utils/request-query.js";
import { idosoParamsSchema } from "./idosos.schemas.js";
import { atualizarIdosoSchema, criarIdosoSchema } from "./idosos.schemas.js";
import { idososService } from "./idosos.service.js";

export const listarIdosos: RequestHandler = asyncHandler(async (_req, res) => {
  const dados = await idososService.listar();
  res.json({ dados, meta: { total: dados.length } });
});

export const buscarIdoso: RequestHandler = asyncHandler(async (req, res) => {
  const { idosoId } = idosoParamsSchema.parse(req.params);
  res.json({ dados: await idososService.buscarPorId(idosoId) });
});

export const criarIdoso: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarIdosoSchema.parse(req.body);
  res.status(201).json({ dados: await idososService.criar(input) });
});

export const atualizarIdoso: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  const input = atualizarIdosoSchema.parse(req.body);
  res.json({ dados: await idososService.atualizar(id, input) });
});

export const removerIdoso: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  await idososService.remover(id, req.body?.usuarioId);
  res.status(204).send();
});
