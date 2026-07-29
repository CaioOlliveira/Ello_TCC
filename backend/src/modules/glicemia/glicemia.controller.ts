import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarGlicemiaSchema,
  criarInsulinaSchema,
  criarGlicemiaSchema,
  historicoGlicemiaQuerySchema,
  resumoGlicemiaQuerySchema,
} from "./glicemia.schemas.js";
import { glicemiaService } from "./glicemia.service.js";

export const listarGlicemias: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await glicemiaService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarGlicemia: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await glicemiaService.buscarPorId(id) });
});

export const obterResumoGlicemia: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      resumoGlicemiaQuerySchema.parse(req.query);
    res.json({
      dados: await glicemiaService.resumo(idosoId, dataReferencia, periodo),
    });
  },
);

export const obterHistoricoGlicemia: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      historicoGlicemiaQuerySchema.parse(req.query);
    res.json({
      dados: await glicemiaService.historico(idosoId, dataReferencia, periodo),
    });
  },
);

export const criarGlicemia: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarGlicemiaSchema.parse(req.body);
  res.status(201).json({ dados: await glicemiaService.criar(input) });
});

export const listarInsulinas: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await glicemiaService.listarInsulinas(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const criarInsulina: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarInsulinaSchema.parse(req.body);
  res.status(201).json({ dados: await glicemiaService.criarInsulina(input) });
});

export const atualizarGlicemia: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarGlicemiaSchema.parse(req.body);
    res.json({ dados: await glicemiaService.atualizar(id, input) });
  },
);

export const removerGlicemia: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await glicemiaService.remover(id);
    res.status(204).send();
  },
);
