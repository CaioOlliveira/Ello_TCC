import type { RequestHandler } from "express";

import { getAuthenticatedUserId } from "../../common/middlewares/authenticated-user.js";
import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  criarMensagemFamiliaSchema,
  listarConversasFamiliaSchema,
  listarMensagensFamiliaSchema,
  marcarMensagensLidasSchema,
  registrarDispositivoPushChatSchema,
  registrarPresencaChatSchema,
} from "./chat-familia.schemas.js";
import { chatFamiliaService } from "./chat-familia.service.js";

export const listarConversasFamilia: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = listarConversasFamiliaSchema.parse(req.query);
    res.json(
      await chatFamiliaService.listarConversas({
        ...input,
        usuarioId: getAuthenticatedUserId(req),
      }),
    );
  },
);

export const listarMensagensFamilia: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = listarMensagensFamiliaSchema.parse(req.query);
    res.json(
      await chatFamiliaService.listarMensagens({
        ...input,
        usuarioId: getAuthenticatedUserId(req),
      }),
    );
  },
);

export const criarMensagemFamilia: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarMensagemFamiliaSchema.parse(req.body);
    res.status(201).json(
      await chatFamiliaService.criarMensagem({
        ...input,
        usuarioId: getAuthenticatedUserId(req),
      }),
    );
  },
);

export const marcarMensagensFamiliaComoLidas: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = marcarMensagensLidasSchema.parse(req.body);
    res.json(
      await chatFamiliaService.marcarMensagensComoLidas({
        ...input,
        usuarioId: getAuthenticatedUserId(req),
      }),
    );
  },
);

export const registrarDispositivoPushChat: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = registrarDispositivoPushChatSchema.parse(req.body);
    await chatFamiliaService.registrarDispositivoPush({
      ...input,
      usuarioId: getAuthenticatedUserId(req),
    });
    res.status(204).send();
  },
);

export const registrarPresencaChat: RequestHandler = asyncHandler(
  async (req, res) => {
    registrarPresencaChatSchema.parse(req.body);
    res.json(
      await chatFamiliaService.registrarPresenca({
        usuarioId: getAuthenticatedUserId(req),
      }),
    );
  },
);

export const apagarConversaFamilia: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = marcarMensagensLidasSchema.parse(req.query);
    await chatFamiliaService.apagarConversa({
      ...input,
      usuarioId: getAuthenticatedUserId(req),
    });
    res.status(204).send();
  },
);
