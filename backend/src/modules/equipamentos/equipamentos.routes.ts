import { Router } from "express";

import {
  atualizarEquipamento,
  buscarEquipamento,
  criarEquipamento,
  listarHistoricoEquipamentos,
  listarManutencoesEquipamento,
  listarEquipamentos,
  registrarManutencaoEquipamento,
  removerEquipamento,
} from "./equipamentos.controller.js";

export const equipamentosRoutes = Router();

equipamentosRoutes.get("/", listarEquipamentos);
equipamentosRoutes.get("/historico", listarHistoricoEquipamentos);
equipamentosRoutes.post("/", criarEquipamento);
equipamentosRoutes.get("/:id", buscarEquipamento);
equipamentosRoutes.patch("/:id", atualizarEquipamento);
equipamentosRoutes.delete("/:id", removerEquipamento);
equipamentosRoutes.get("/:id/manutencoes", listarManutencoesEquipamento);
equipamentosRoutes.post("/:id/manutencoes", registrarManutencaoEquipamento);
