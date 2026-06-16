import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import { atualizarEventoSchema, criarEventoSchema } from "./agenda.schemas.js";
import { agendaService } from "./agenda.service.js";

export const listarCompromissos: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await agendaService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await agendaService.buscarPorId(id) });
  },
);

export const criarCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarEventoSchema.parse(req.body);
    res.status(201).json({ dados: await agendaService.criar(input) });
  },
);

export const atualizarCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarEventoSchema.parse(req.body);
    res.json({ dados: await agendaService.atualizar(id, input) });
  },
);

export const removerCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await agendaService.remover(id);
    res.status(204).send();
  },
);
