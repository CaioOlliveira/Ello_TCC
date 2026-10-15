import { Router } from "express";
import { requireFichaAccessFromQuery } from "../../common/auth/ficha-access.js";

import {
  atualizarPressao,
  buscarPressao,
  criarPressao,
  listarPressoes,
  obterHistoricoPressao,
  obterResumoPressao,
  removerPressao,
} from "./pressao.controller.js";

export const pressaoRoutes = Router();

pressaoRoutes.get("/", listarPressoes);
pressaoRoutes.get("/resumo", obterResumoPressao);
pressaoRoutes.get("/historico", requireFichaAccessFromQuery, obterHistoricoPressao);
pressaoRoutes.post("/", criarPressao);
pressaoRoutes.get("/:id", buscarPressao);
pressaoRoutes.patch("/:id", atualizarPressao);
pressaoRoutes.delete("/:id", removerPressao);
