import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarPressaoSchema,
  criarPressaoSchema,
  historicoPressaoQuerySchema,
  resumoPressaoQuerySchema,
} from "./pressao.schemas.js";
import { pressaoService } from "./pressao.service.js";

export const listarPressoes: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await pressaoService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarPressao: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await pressaoService.buscarPorId(id) });
});

export const obterResumoPressao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } = resumoPressaoQuerySchema.parse(
      req.query,
    );
    res.json({
      dados: await pressaoService.resumo(idosoId, dataReferencia, periodo),
    });
  },
);

export const obterHistoricoPressao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      historicoPressaoQuerySchema.parse(req.query);
    res.json({
      dados: await pressaoService.historico(idosoId, dataReferencia, periodo),
    });
  },
);

export const criarPressao: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarPressaoSchema.parse(req.body);
  res.status(201).json({ dados: await pressaoService.criar(input) });
});

export const atualizarPressao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarPressaoSchema.parse(req.body);
    res.json({ dados: await pressaoService.atualizar(id, input) });
  },
);

export const removerPressao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await pressaoService.remover(id);
    res.status(204).send();
  },
);
