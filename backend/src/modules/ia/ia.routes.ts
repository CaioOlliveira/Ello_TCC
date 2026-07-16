import { Router } from "express";

import {
  criarConversaIa,
  listarConversasIa,
  listarMensagensIa,
  obterRelatorioInicialIa,
  perguntarIa,
} from "./ia.controller.js";

export const iaRoutes = Router();

iaRoutes.get("/conversas", listarConversasIa);
iaRoutes.post("/conversas", criarConversaIa);
iaRoutes.get("/conversas/:id/mensagens", listarMensagensIa);
iaRoutes.get("/relatorio-inicial", obterRelatorioInicialIa);
iaRoutes.post("/perguntar", perguntarIa);
