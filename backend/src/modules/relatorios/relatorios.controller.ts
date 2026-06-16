import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarRelatorioSchema,
  criarRelatorioSchema,
} from "./relatorios.schemas.js";
import { relatoriosService } from "./relatorios.service.js";

export const listarRelatorios: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await relatoriosService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarRelatorio: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await relatoriosService.buscarPorId(id) });
  },
);

export const criarRelatorio: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarRelatorioSchema.parse(req.body);
  res.status(201).json({ dados: await relatoriosService.criar(input) });
});

export const atualizarRelatorio: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarRelatorioSchema.parse(req.body);
    res.json({ dados: await relatoriosService.atualizar(id, input) });
  },
);

export const removerRelatorio: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await relatoriosService.remover(id);
    res.status(204).send();
  },
);
