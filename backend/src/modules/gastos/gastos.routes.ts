import { Router } from "express";

import { requireAuthenticatedUser } from "../../common/middlewares/authenticated-user.js";
import {
  atualizarGasto,
  criarGasto,
  listarGastos,
  removerGasto,
} from "./gastos.controller.js";

export const gastosRoutes = Router();

gastosRoutes.use(requireAuthenticatedUser);
gastosRoutes.get("/", listarGastos);
gastosRoutes.post("/", criarGasto);
gastosRoutes.patch("/:id", atualizarGasto);
gastosRoutes.delete("/:id", removerGasto);
