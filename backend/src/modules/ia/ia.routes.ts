import { Router } from "express";

import {
  criarConversaIa,
  listarConversasIa,
  listarMensagensIa,
  perguntarIa,
} from "./ia.controller.js";

export const iaRoutes = Router();

iaRoutes.get("/conversas", listarConversasIa);
iaRoutes.post("/conversas", criarConversaIa);
iaRoutes.get("/conversas/:id/mensagens", listarMensagensIa);
iaRoutes.post("/perguntar", perguntarIa);
