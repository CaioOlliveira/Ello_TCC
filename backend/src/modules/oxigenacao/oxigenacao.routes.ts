import { Router } from "express";

import {
  atualizarOxigenacao,
  buscarOxigenacao,
  criarOxigenacao,
  listarOxigenacoes,
  obterHistoricoOxigenacao,
  obterResumoOxigenacao,
  removerOxigenacao,
} from "./oxigenacao.controller.js";

export const oxigenacaoRoutes = Router();

oxigenacaoRoutes.get("/", listarOxigenacoes);
oxigenacaoRoutes.get("/resumo", obterResumoOxigenacao);
oxigenacaoRoutes.get("/historico", obterHistoricoOxigenacao);
oxigenacaoRoutes.post("/", criarOxigenacao);
oxigenacaoRoutes.get("/:id", buscarOxigenacao);
oxigenacaoRoutes.patch("/:id", atualizarOxigenacao);
oxigenacaoRoutes.delete("/:id", removerOxigenacao);
