import { Router } from "express";

import {
  atualizarRelatorio,
  buscarRelatorio,
  criarRelatorio,
  listarRelatorios,
  removerRelatorio,
} from "./relatorios.controller.js";

export const relatoriosRoutes = Router();

relatoriosRoutes.get("/", listarRelatorios);
relatoriosRoutes.post("/", criarRelatorio);
relatoriosRoutes.get("/:id", buscarRelatorio);
relatoriosRoutes.patch("/:id", atualizarRelatorio);
relatoriosRoutes.delete("/:id", removerRelatorio);
