import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import { atualizarMembroSchema, criarMembroSchema } from "./membros.schemas.js";
import { membrosService } from "./membros.service.js";

export const listarMembros: RequestHandler = asyncHandler(async (req, res) => {
  const { limite, offset, pagina } = getPagination(req.query);
  const idosoId =
    typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
  const { dados, total } = await membrosService.listar(limite, offset, idosoId);
  res.json({ dados, meta: { total, pagina, limite } });
});

export const buscarMembro: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await membrosService.buscarPorId(id) });
});

export const criarMembro: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarMembroSchema.parse(req.body);
  res.status(201).json({ dados: await membrosService.criar(input) });
});

export const atualizarMembro: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarMembroSchema.parse(req.body);
    res.json({ dados: await membrosService.atualizar(id, input) });
  },
);

export const removerMembro: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  await membrosService.remover(id);
  res.status(204).send();
});
