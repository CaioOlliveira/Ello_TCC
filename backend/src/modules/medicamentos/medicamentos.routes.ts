import { Router } from "express";

import {
  atualizarMedicamento,
  buscarMedicamento,
  criarHorarioMedicamento,
  criarMedicamento,
  listarHorariosMedicamento,
  listarMedicamentos,
  registrarAdministracaoMedicamento,
  removerMedicamento,
} from "./medicamentos.controller.js";

export const medicamentosRoutes = Router();

medicamentosRoutes.get("/", listarMedicamentos);
medicamentosRoutes.post("/", criarMedicamento);
medicamentosRoutes.get("/:id", buscarMedicamento);
medicamentosRoutes.patch("/:id", atualizarMedicamento);
medicamentosRoutes.delete("/:id", removerMedicamento);
medicamentosRoutes.get("/:id/horarios", listarHorariosMedicamento);
medicamentosRoutes.post("/:id/horarios", criarHorarioMedicamento);
medicamentosRoutes.post(
  "/:id/administracoes",
  registrarAdministracaoMedicamento,
);
