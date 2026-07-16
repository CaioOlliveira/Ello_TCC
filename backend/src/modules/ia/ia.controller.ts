import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import { idParamSchema } from "../../common/utils/request-query.js";
import { iaService } from "./ia.service.js";
import {
  criarConversaIaSchema,
  listarConversasIaSchema,
  listarMensagensIaSchema,
  perguntarIaSchema,
  relatorioInicialIaSchema,
} from "./ia.schemas.js";

export const listarConversasIa: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = listarConversasIaSchema.parse(req.query);
    res.json(await iaService.listarConversas(input));
  },
);

export const criarConversaIa: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarConversaIaSchema.parse(req.body);
    res.status(201).json(await iaService.criarConversa(input));
  },
);

export const listarMensagensIa: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const { usuarioId } = listarMensagensIaSchema.parse(req.query);
    res.json(await iaService.listarMensagens(id, usuarioId));
  },
);

export const perguntarIa: RequestHandler = asyncHandler(async (req, res) => {
  const input = perguntarIaSchema.parse(req.body);
  res.json(await iaService.perguntar(input));
});

export const obterRelatorioInicialIa: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = relatorioInicialIaSchema.parse(req.query);
    res.json({ dados: await iaService.obterRelatorioInicial(input) });
  },
);
