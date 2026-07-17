import { Router } from "express";

import { listarHistorico } from "./historico.controller.js";

export const historicoRoutes = Router();

historicoRoutes.get("/", listarHistorico);
