import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import { criarRefeicaoSchema } from "./alimentacao.schemas.js";
import { alimentacaoService } from "./alimentacao.service.js";

export const listarRefeicoes: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await alimentacaoService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarRefeicao: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await alimentacaoService.buscarPorId(id) });
});

export const criarRefeicao: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarRefeicaoSchema.parse(req.body);
  res.status(201).json({ dados: await alimentacaoService.criar(input) });
});

export const removerRefeicao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await alimentacaoService.remover(id);
    res.status(204).send();
  },
);
