import { Router } from "express";

import {
  atualizarGlicemia,
  buscarGlicemia,
  criarGlicemia,
  listarGlicemias,
  removerGlicemia,
} from "./glicemia.controller.js";

export const glicemiaRoutes = Router();

glicemiaRoutes.get("/", listarGlicemias);
glicemiaRoutes.post("/", criarGlicemia);
glicemiaRoutes.get("/:id", buscarGlicemia);
glicemiaRoutes.patch("/:id", atualizarGlicemia);
glicemiaRoutes.delete("/:id", removerGlicemia);
