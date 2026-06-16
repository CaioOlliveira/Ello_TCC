import { Router } from "express";

import {
  atualizarIdoso,
  buscarIdoso,
  criarIdoso,
  listarIdosos,
  removerIdoso,
} from "./idosos.controller.js";

export const idososRoutes = Router();

idososRoutes.get("/", listarIdosos);
idososRoutes.post("/", criarIdoso);
idososRoutes.get("/:idosoId", buscarIdoso);
idososRoutes.patch("/:id", atualizarIdoso);
idososRoutes.delete("/:id", removerIdoso);
