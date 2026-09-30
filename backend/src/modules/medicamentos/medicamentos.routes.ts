import { Router } from "express";

import { requireAuthenticatedUser } from "../../common/middlewares/authenticated-user.js";
import {
  atualizarMedicamento,
  buscarMedicamento,
  cancelarAdministracaoMedicamento,
  criarHorarioMedicamento,
  criarMedicamento,
  listarAdministracoesMedicamento,
  listarHorariosMedicamento,
  listarMedicamentos,
  listarSolicitacoesCancelamento,
  obterHistoricoMedicamentos,
  obterResumoMedicamentos,
  registrarAdministracaoMedicamento,
  responderSolicitacaoCancelamento,
  removerMedicamento,
  substituirHorariosMedicamento,
  solicitarCancelamentoAdministracao,
} from "./medicamentos.controller.js";

export const medicamentosRoutes = Router();

medicamentosRoutes.get("/", listarMedicamentos);
medicamentosRoutes.post("/", criarMedicamento);
medicamentosRoutes.get("/resumo", obterResumoMedicamentos);
medicamentosRoutes.get("/historico", obterHistoricoMedicamentos);
medicamentosRoutes.get(
  "/solicitacoes-cancelamento",
  requireAuthenticatedUser,
  listarSolicitacoesCancelamento,
);
medicamentosRoutes.post(
  "/solicitacoes-cancelamento/:id/responder",
  requireAuthenticatedUser,
  responderSolicitacaoCancelamento,
);
medicamentosRoutes.get("/:id", buscarMedicamento);
medicamentosRoutes.patch("/:id", atualizarMedicamento);
medicamentosRoutes.delete("/:id", removerMedicamento);
medicamentosRoutes.get("/:id/horarios", listarHorariosMedicamento);
medicamentosRoutes.post("/:id/horarios", criarHorarioMedicamento);
medicamentosRoutes.put("/:id/horarios", substituirHorariosMedicamento);
medicamentosRoutes.get("/:id/administracoes", listarAdministracoesMedicamento);
medicamentosRoutes.post(
  "/:id/administracoes",
  registrarAdministracaoMedicamento,
);
medicamentosRoutes.delete(
  "/:id/administracoes/:administracaoId",
  requireAuthenticatedUser,
  cancelarAdministracaoMedicamento,
);
medicamentosRoutes.post(
  "/:id/administracoes/:administracaoId/solicitacoes-cancelamento",
  requireAuthenticatedUser,
  solicitarCancelamentoAdministracao,
);
