import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarMembroSchema,
  criarMembroSchema,
  listarParticipantesQuerySchema,
  registrarPresencaSchema,
} from "./membros.schemas.js";
import { membrosService } from "./membros.service.js";

export const listarMembros: RequestHandler = asyncHandler(async (req, res) => {
  const { limite, offset, pagina } = getPagination(req.query);
  const idosoId =
    typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
  const { dados, total } = await membrosService.listar(limite, offset, idosoId);
  res.json({ dados, meta: { total, pagina, limite } });
});

export const listarParticipantes: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId } = listarParticipantesQuerySchema.parse(req.query);
    const dados = await membrosService.listarParticipantes(idosoId);
    res.json({ dados, meta: { total: dados.length } });
  },
);

export const listarPendentes: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId } = listarParticipantesQuerySchema.parse(req.query);
    const dados = await membrosService.listarPendentes(idosoId);
    res.json({ dados, meta: { total: dados.length } });
  },
);

export const registrarPresenca: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = registrarPresencaSchema.parse(req.body);
    res.json({ dados: await membrosService.registrarPresenca(input) });
  },
);

export const buscarMembro: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await membrosService.buscarComUsuario(id) });
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

export const aprovarMembro: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await membrosService.aprovar(id, req.body?.usuarioId) });
});

export const negarMembro: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await membrosService.negar(id, req.body?.usuarioId) });
});

export const revogarMembro: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await membrosService.revogar(id, req.body?.usuarioId) });
});

export const removerMembro: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  await membrosService.remover(id);
  res.status(204).send();
});
