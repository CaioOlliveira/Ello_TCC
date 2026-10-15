import { Router } from "express";

import { listarHistorico } from "./historico.controller.js";
import { requireAuthenticatedUser } from "../../common/middlewares/authenticated-user.js";

export const historicoRoutes = Router();

historicoRoutes.get("/", requireAuthenticatedUser, listarHistorico);
