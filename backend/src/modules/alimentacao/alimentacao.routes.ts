import { Router } from "express";

import {
  atualizarRefeicao,
  buscarRefeicao,
  buscarDicaAlimentacao,
  concluirRefeicao,
  criarRefeicao,
  removerRecordatorioRefeicao,
  listarRefeicoes,
  removerRefeicao,
} from "./alimentacao.controller.js";

export const alimentacaoRoutes = Router();

alimentacaoRoutes.get("/", listarRefeicoes);
alimentacaoRoutes.get("/dica", buscarDicaAlimentacao);
alimentacaoRoutes.post("/", criarRefeicao);
alimentacaoRoutes.get("/:id", buscarRefeicao);
alimentacaoRoutes.patch("/:id", atualizarRefeicao);
alimentacaoRoutes.post("/:id/concluir", concluirRefeicao);
alimentacaoRoutes.delete("/:id/recordatorio", removerRecordatorioRefeicao);
alimentacaoRoutes.delete("/:id", removerRefeicao);
