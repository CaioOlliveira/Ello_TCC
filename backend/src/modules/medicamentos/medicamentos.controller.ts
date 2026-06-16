import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  atualizarMedicamentoSchema,
  criarHorarioMedicamentoSchema,
  criarMedicamentoSchema,
  registrarAdministracaoSchema,
} from "./medicamentos.schemas.js";
import { medicamentosService } from "./medicamentos.service.js";

export const listarMedicamentos: RequestHandler = asyncHandler(
  async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await medicamentosService.listar(
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  },
);

export const buscarMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    res.json({ dados: await medicamentosService.buscarPorId(id) });
  },
);

export const criarMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = criarMedicamentoSchema.parse(req.body);
    res.status(201).json({ dados: await medicamentosService.criar(input) });
  },
);

export const atualizarMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarMedicamentoSchema.parse(req.body);
    res.json({ dados: await medicamentosService.atualizar(id, input) });
  },
);

export const removerMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    await medicamentosService.remover(id);
    res.status(204).send();
  },
);

export const listarHorariosMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const dados = await medicamentosService.listarHorarios(id);
    res.json({ dados, meta: { total: dados.length } });
  },
);

export const criarHorarioMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = criarHorarioMedicamentoSchema.parse(req.body);
    res
      .status(201)
      .json({ dados: await medicamentosService.criarHorario(id, input) });
  },
);

export const registrarAdministracaoMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = registrarAdministracaoSchema.parse(req.body);
    res.status(201).json({
      dados: await medicamentosService.registrarAdministracao(id, input),
    });
  },
);
