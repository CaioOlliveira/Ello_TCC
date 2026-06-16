import { Router } from "express";

import {
  buscarRefeicao,
  criarRefeicao,
  listarRefeicoes,
  removerRefeicao,
} from "./alimentacao.controller.js";

export const alimentacaoRoutes = Router();

alimentacaoRoutes.get("/", listarRefeicoes);
alimentacaoRoutes.post("/", criarRefeicao);
alimentacaoRoutes.get("/:id", buscarRefeicao);
alimentacaoRoutes.delete("/:id", removerRefeicao);
