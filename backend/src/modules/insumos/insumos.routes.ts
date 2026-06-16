import { Router } from "express";

import {
  atualizarInsumo,
  buscarInsumo,
  criarInsumo,
  criarMovimentacaoInsumo,
  listarInsumos,
  listarMovimentacoesInsumo,
  removerInsumo,
} from "./insumos.controller.js";

export const insumosRoutes = Router();

insumosRoutes.get("/", listarInsumos);
insumosRoutes.post("/", criarInsumo);
insumosRoutes.get("/:id", buscarInsumo);
insumosRoutes.patch("/:id", atualizarInsumo);
insumosRoutes.delete("/:id", removerInsumo);
insumosRoutes.get("/:id/movimentacoes", listarMovimentacoesInsumo);
insumosRoutes.post("/:insumoId/movimentacoes", criarMovimentacaoInsumo);
