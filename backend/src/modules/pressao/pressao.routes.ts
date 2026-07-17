import { Router } from "express";

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
pressaoRoutes.get("/historico", obterHistoricoPressao);
pressaoRoutes.post("/", criarPressao);
pressaoRoutes.get("/:id", buscarPressao);
pressaoRoutes.patch("/:id", atualizarPressao);
pressaoRoutes.delete("/:id", removerPressao);
