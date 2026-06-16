import { Router } from "express";

import {
  atualizarNotificacao,
  buscarNotificacao,
  criarNotificacao,
  listarNotificacoes,
  marcarNotificacaoComoLida,
  removerNotificacao,
} from "./notificacoes.controller.js";

export const notificacoesRoutes = Router();

notificacoesRoutes.get("/", listarNotificacoes);
notificacoesRoutes.post("/", criarNotificacao);
notificacoesRoutes.get("/:id", buscarNotificacao);
notificacoesRoutes.patch("/:id", atualizarNotificacao);
notificacoesRoutes.post("/:id/lida", marcarNotificacaoComoLida);
notificacoesRoutes.delete("/:id", removerNotificacao);
