import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarNotificacaoSchema,
  criarNotificacaoSchema,
} from "./notificacoes.schemas.js";
import { notificacoesService } from "./notificacoes.service.js";

export const listarNotificacoes: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const usuarioId =
      typeof req.query.usuarioId === "string" ? req.query.usuarioId : undefined;
    const { dados, total } = await notificacoesService.listar(
      limite,
      offset,
      usuarioId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarNotificacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await notificacoesService.buscarPorId(id) });
  },
);

export const criarNotificacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarNotificacaoSchema.parse(req.body);
    res.status(201).json({ dados: await notificacoesService.criar(input) });
  },
);

export const atualizarNotificacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarNotificacaoSchema.parse(req.body);
    res.json({ dados: await notificacoesService.atualizar(id, input) });
  },
);

export const marcarNotificacaoComoLida: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await notificacoesService.marcarComoLida(id) });
  },
);

export const removerNotificacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await notificacoesService.remover(id);
    res.status(204).send();
  },
);
