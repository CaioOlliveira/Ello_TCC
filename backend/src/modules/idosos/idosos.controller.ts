import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import { idParamSchema } from "../../common/utils/request-query.js";
import {
  idosoParamsSchema,
  listarIdososQuerySchema,
} from "./idosos.schemas.js";
import { atualizarIdosoSchema, criarIdosoSchema } from "./idosos.schemas.js";
import { idososService } from "./idosos.service.js";

export const listarIdosos: RequestHandler = asyncHandler(async (req, res) => {
  const { usuarioId } = listarIdososQuerySchema.parse(req.query);
  const dados = await idososService.listar({ usuarioId });
  res.json({ dados, meta: { total: dados.length } });
});

export const listarIdososAdministrados: RequestHandler = asyncHandler(
  async (req, res) => {
    const { usuarioId } = listarIdososQuerySchema.parse(req.query);
    if (!usuarioId) {
      res.json({ dados: [], meta: { total: 0 } });
      return;
    }
    const dados = await idososService.listarAdministrados(usuarioId);
    res.json({ dados, meta: { total: dados.length } });
  },
);

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
