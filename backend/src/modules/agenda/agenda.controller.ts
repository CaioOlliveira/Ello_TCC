import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarEventoSchema,
  atualizarOcorrenciaEventoSchema,
  criarEventoSchema,
} from "./agenda.schemas.js";
import { agendaService } from "./agenda.service.js";
import { getAuthenticatedUserId } from "../../common/middlewares/authenticated-user.js";
import { validarAcessoFicha } from "../../common/auth/ficha-access.js";
import { AppError } from "../../common/errors/app-error.js";

const fichaIdDaQuery = (value: unknown) => {
  if (typeof value !== "string" || !value) {
    throw new AppError("FICHA_OBRIGATORIA", "Selecione uma ficha.", 400);
  }
  return value;
};

const validarAcessoCompromisso = async (id: string, usuarioId: string) => {
  const compromisso = await agendaService.buscarPorId(id);
  await validarAcessoFicha(String(compromisso.idoso_id), usuarioId);
};

export const listarCompromissos: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId = fichaIdDaQuery(req.query.idosoId);
    await validarAcessoFicha(idosoId, getAuthenticatedUserId(req));
    const { dados, total } = await agendaService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const listarHistoricoAgenda: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId = fichaIdDaQuery(req.query.idosoId);
    await validarAcessoFicha(idosoId, getAuthenticatedUserId(req));
    const { dados, total } = await agendaService.listarHistorico(
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
    await validarAcessoCompromisso(id, getAuthenticatedUserId(req));
    res.json({ dados: await agendaService.buscarPorId(id) });
  },
);

export const criarCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarEventoSchema.parse(req.body);
    const usuarioId = getAuthenticatedUserId(req);
    await validarAcessoFicha(input.idosoId, usuarioId);
    res
      .status(201)
      .json({
        dados: await agendaService.criar({ ...input, criadoPorId: usuarioId }),
      });
  },
);

export const atualizarCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarEventoSchema.parse(req.body);
    const usuarioId = getAuthenticatedUserId(req);
    await validarAcessoCompromisso(id, usuarioId);
    res.json({
      dados: await agendaService.atualizar(id, {
        ...input,
        criadoPorId: usuarioId,
      }),
    });
  },
);

export const atualizarOcorrenciaCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarOcorrenciaEventoSchema.parse(req.body);
    const usuarioId = getAuthenticatedUserId(req);
    await validarAcessoCompromisso(id, usuarioId);
    res.json({
      dados: await agendaService.atualizarOcorrencia(id, input, usuarioId),
    });
  },
);

export const removerCompromisso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const usuarioId = getAuthenticatedUserId(req);
    await validarAcessoCompromisso(id, usuarioId);
    await agendaService.remover(id, usuarioId);
    res.status(204).send();
  },
);
