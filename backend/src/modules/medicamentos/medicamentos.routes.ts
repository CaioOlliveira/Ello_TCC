import { Router } from "express";

import {
  atualizarMedicamento,
  buscarMedicamento,
  cancelarAdministracaoMedicamento,
  criarHorarioMedicamento,
  criarMedicamento,
  listarAdministracoesMedicamento,
  listarHorariosMedicamento,
  listarMedicamentos,
  obterHistoricoMedicamentos,
  obterResumoMedicamentos,
  registrarAdministracaoMedicamento,
  removerMedicamento,
  substituirHorariosMedicamento,
} from "./medicamentos.controller.js";

export const medicamentosRoutes = Router();

medicamentosRoutes.get("/", listarMedicamentos);
medicamentosRoutes.post("/", criarMedicamento);
medicamentosRoutes.get("/resumo", obterResumoMedicamentos);
medicamentosRoutes.get("/historico", obterHistoricoMedicamentos);
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
  cancelarAdministracaoMedicamento,
);
