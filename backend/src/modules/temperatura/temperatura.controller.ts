import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarTemperaturaSchema,
  criarTemperaturaSchema,
  historicoTemperaturaQuerySchema,
  resumoTemperaturaQuerySchema,
} from "./temperatura.schemas.js";
import { temperaturaService } from "./temperatura.service.js";

export const listarTemperaturas: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await temperaturaService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarTemperatura: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await temperaturaService.buscarPorId(id) });
  },
);

export const obterResumoTemperatura: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      resumoTemperaturaQuerySchema.parse(req.query);
    res.json({
      dados: await temperaturaService.resumo(idosoId, dataReferencia, periodo),
    });
  },
);

export const obterHistoricoTemperatura: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      historicoTemperaturaQuerySchema.parse(req.query);
    res.json({
      dados: await temperaturaService.historico(
        idosoId,
        dataReferencia,
        periodo,
      ),
    });
  },
);

export const criarTemperatura: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarTemperaturaSchema.parse(req.body);
    res.status(201).json({ dados: await temperaturaService.criar(input) });
  },
);

export const atualizarTemperatura: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarTemperaturaSchema.parse(req.body);
    res.json({ dados: await temperaturaService.atualizar(id, input) });
  },
);

export const removerTemperatura: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await temperaturaService.remover(id);
    res.status(204).send();
  },
);
