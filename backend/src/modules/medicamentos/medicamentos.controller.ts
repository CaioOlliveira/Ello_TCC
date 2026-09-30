import type { RequestHandler } from "express";

import { getAuthenticatedUserId } from "../../common/middlewares/authenticated-user.js";
import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  getPagination,
  idParamSchema,
} from "../../common/utils/request-query.js";
import {
  administracaoParamSchema,
  atualizarMedicamentoSchema,
  cancelarAdministracaoSchema,
  criarHorarioMedicamentoSchema,
  criarMedicamentoSchema,
  historicoMedicamentosQuerySchema,
  listarSolicitacoesCancelamentoSchema,
  registrarAdministracaoSchema,
  responderSolicitacaoCancelamentoSchema,
  resumoMedicamentosQuerySchema,
  substituirHorariosMedicamentoSchema,
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

export const obterResumoMedicamentos: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId } = resumoMedicamentosQuerySchema.parse(req.query);
    res.json({ dados: await medicamentosService.resumo(idosoId) });
  },
);

export const obterHistoricoMedicamentos: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId, dataReferencia, periodo } =
      historicoMedicamentosQuerySchema.parse(req.query);
    res.json({
      dados: await medicamentosService.historico(
        idosoId,
        dataReferencia,
        periodo,
      ),
    });
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
    const usuarioId =
      typeof req.query.usuarioId === "string" ? req.query.usuarioId : undefined;
    await medicamentosService.remover(id, usuarioId);
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

export const cancelarAdministracaoMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const { administracaoId } = administracaoParamSchema.parse(req.params);
    const input = cancelarAdministracaoSchema.parse(req.body);
    res.json({
      dados: await medicamentosService.cancelarAdministracao(
        id,
        administracaoId,
        input.idosoId,
        getAuthenticatedUserId(req),
      ),
    });
  },
);

export const solicitarCancelamentoAdministracao: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const { administracaoId } = administracaoParamSchema.parse(req.params);
    const input = cancelarAdministracaoSchema.parse(req.body);
    res.status(201).json({
      dados: await medicamentosService.solicitarCancelamentoAdministracao(
        id,
        administracaoId,
        input.idosoId,
        getAuthenticatedUserId(req),
      ),
    });
  },
);

export const listarSolicitacoesCancelamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId } = listarSolicitacoesCancelamentoSchema.parse(req.query);
    res.json({
      dados: await medicamentosService.listarSolicitacoesCancelamento(
        idosoId,
        getAuthenticatedUserId(req),
      ),
    });
  },
);

export const responderSolicitacaoCancelamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id: solicitacaoId } = idParamSchema.parse(req.params);
    const input = responderSolicitacaoCancelamentoSchema.parse(req.body);
    res.json({
      dados: await medicamentosService.responderSolicitacaoCancelamento(
        solicitacaoId,
        input.aprovar,
        getAuthenticatedUserId(req),
      ),
    });
  },
);

export const listarAdministracoesMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const dados = await medicamentosService.listarAdministracoes(id);
    res.json({ dados, meta: { total: dados.length } });
  },
);

export const substituirHorariosMedicamento: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = substituirHorariosMedicamentoSchema.parse(req.body);
    res.json({
      dados: await medicamentosService.substituirHorarios(id, input),
    });
  },
);
