import { Router } from "express";

import {
  atualizarTemperatura,
  buscarTemperatura,
  criarTemperatura,
  listarTemperaturas,
  obterHistoricoTemperatura,
  obterResumoTemperatura,
  removerTemperatura,
} from "./temperatura.controller.js";

export const temperaturaRoutes = Router();

temperaturaRoutes.get("/", listarTemperaturas);
temperaturaRoutes.get("/resumo", obterResumoTemperatura);
temperaturaRoutes.get("/historico", obterHistoricoTemperatura);
temperaturaRoutes.post("/", criarTemperatura);
temperaturaRoutes.get("/:id", buscarTemperatura);
temperaturaRoutes.patch("/:id", atualizarTemperatura);
temperaturaRoutes.delete("/:id", removerTemperatura);
