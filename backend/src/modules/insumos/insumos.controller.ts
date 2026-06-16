import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarInsumoSchema,
  criarInsumoSchema,
  criarMovimentacaoInsumoSchema,
  insumoParamsSchema,
} from "./insumos.schemas.js";
import { insumosService } from "./insumos.service.js";

export const listarInsumos: RequestHandler = asyncHandler(async (req, res) => {
  const { limite, offset, pagina } = getPagination(req.query);
  const idosoId =
    typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
  const { dados, total } = await insumosService.listar(limite, offset, idosoId);
  res.json({ dados, meta: { total, pagina, limite } });
});

export const buscarInsumo: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await insumosService.buscarPorId(id) });
});

export const criarInsumo: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarInsumoSchema.parse(req.body);
  res.status(201).json({ dados: await insumosService.criar(input) });
});

export const atualizarInsumo: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarInsumoSchema.parse(req.body);
    res.json({ dados: await insumosService.atualizar(id, input) });
  },
);

export const removerInsumo: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  await insumosService.remover(id);
  res.status(204).send();
});

export const listarMovimentacoesInsumo: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const dados = await insumosService.listarMovimentacoes(id);
    res.json({ dados, meta: { total: dados.length } });
  },
);

export const criarMovimentacaoInsumo: RequestHandler = asyncHandler(
  async (req, res) => {
    const { insumoId } = insumoParamsSchema.parse(req.params);
    const input = criarMovimentacaoInsumoSchema.parse(req.body);
    res
      .status(201)
      .json({ dados: await insumosService.movimentar(insumoId, input) });
  },
);
