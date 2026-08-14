import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  criarMensagemFamiliaSchema,
  listarMensagensFamiliaSchema,
} from "./chat-familia.schemas.js";
import { chatFamiliaService } from "./chat-familia.service.js";

export const listarMensagensFamilia: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = listarMensagensFamiliaSchema.parse(req.query);
    res.json(await chatFamiliaService.listarMensagens(input));
  },
);

export const criarMensagemFamilia: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarMensagemFamiliaSchema.parse(req.body);
    res.status(201).json(await chatFamiliaService.criarMensagem(input));
  },
);
