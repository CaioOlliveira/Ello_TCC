import { Router } from "express";

import { requireAuthenticatedUser } from "../../common/middlewares/authenticated-user.js";
import { criarGasto, listarGastos } from "./gastos.controller.js";

export const gastosRoutes = Router();

gastosRoutes.use(requireAuthenticatedUser);
gastosRoutes.get("/", listarGastos);
gastosRoutes.post("/", criarGasto);
