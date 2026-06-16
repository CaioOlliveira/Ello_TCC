import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  aceitarConviteSchema,
  atualizarConviteSchema,
  criarConviteSchema,
} from "./convites.schemas.js";
import { convitesService } from "./convites.service.js";

export const listarConvites: RequestHandler = asyncHandler(async (req, res) => {
  const { limite, offset, pagina } = getPagination(req.query);
  const { dados, total } = await convitesService.listar(limite, offset);
  res.json({ dados, meta: { total, pagina, limite } });
});

export const buscarConvite: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await convitesService.buscarPorId(id) });
});

export const criarConvite: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarConviteSchema.parse(req.body);
  res.status(201).json({ dados: await convitesService.criar(input) });
});

export const atualizarConvite: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarConviteSchema.parse(req.body);
    res.json({ dados: await convitesService.atualizar(id, input) });
  },
);

export const revogarConvite: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await convitesService.revogar(id, req.body?.usuarioId) });
});

export const aceitarConvite: RequestHandler = asyncHandler(async (req, res) => {
  const input = aceitarConviteSchema.parse(req.body);
  res.json({ dados: await convitesService.aceitar(input) });
});
