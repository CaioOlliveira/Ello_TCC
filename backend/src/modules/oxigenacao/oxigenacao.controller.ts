import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarOxigenacaoSchema,
  criarOxigenacaoSchema,
  historicoOxigenacaoQuerySchema,
  resumoOxigenacaoQuerySchema,
} from "./oxigenacao.schemas.js";
import { oxigenacaoService } from "./oxigenacao.service.js";

export const listarOxigenacoes: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await oxigenacaoService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarOxigenacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await oxigenacaoService.buscarPorId(id) });
  },
);

export const obterResumoOxigenacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      resumoOxigenacaoQuerySchema.parse(req.query);
    res.json({
      dados: await oxigenacaoService.resumo(idosoId, dataReferencia, periodo),
    });
  },
);

export const obterHistoricoOxigenacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      historicoOxigenacaoQuerySchema.parse(req.query);
    res.json({
      dados: await oxigenacaoService.historico(
        idosoId,
        dataReferencia,
        periodo,
      ),
    });
  },
);

export const criarOxigenacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarOxigenacaoSchema.parse(req.body);
    res.status(201).json({ dados: await oxigenacaoService.criar(input) });
  },
);

export const atualizarOxigenacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarOxigenacaoSchema.parse(req.body);
    res.json({ dados: await oxigenacaoService.atualizar(id, input) });
  },
);

export const removerOxigenacao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await oxigenacaoService.remover(id);
    res.status(204).send();
  },
);
