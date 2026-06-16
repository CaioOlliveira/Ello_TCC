import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarEquipamentoSchema,
  criarEquipamentoSchema,
  criarManutencaoSchema,
} from "./equipamentos.schemas.js";
import { equipamentosService } from "./equipamentos.service.js";

export const listarEquipamentos: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await equipamentosService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarEquipamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await equipamentosService.buscarPorId(id) });
  },
);

export const criarEquipamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarEquipamentoSchema.parse(req.body);
    res.status(201).json({ dados: await equipamentosService.criar(input) });
  },
);

export const atualizarEquipamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarEquipamentoSchema.parse(req.body);
    res.json({ dados: await equipamentosService.atualizar(id, input) });
  },
);

export const removerEquipamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await equipamentosService.remover(id);
    res.status(204).send();
  },
);

export const registrarManutencaoEquipamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = criarManutencaoSchema.parse(req.body);
    res.status(201).json({
      dados: await equipamentosService.registrarManutencao(id, input),
    });
  },
);
