import { Router } from "express";
import { requireFichaAccessFromQuery } from "../../common/auth/ficha-access.js";

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
equipamentosRoutes.get("/historico", requireFichaAccessFromQuery, listarHistoricoEquipamentos);
equipamentosRoutes.post("/", criarEquipamento);
equipamentosRoutes.get("/:id", buscarEquipamento);
equipamentosRoutes.patch("/:id", atualizarEquipamento);
equipamentosRoutes.delete("/:id", removerEquipamento);
equipamentosRoutes.get("/:id/manutencoes", listarManutencoesEquipamento);
equipamentosRoutes.post("/:id/manutencoes", registrarManutencaoEquipamento);
