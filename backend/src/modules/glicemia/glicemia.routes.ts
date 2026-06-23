import { Router } from "express";

import {
  atualizarGlicemia,
  buscarGlicemia,
  criarInsulina,
  criarGlicemia,
  listarInsulinas,
  listarGlicemias,
  obterResumoGlicemia,
  removerGlicemia,
} from "./glicemia.controller.js";

export const glicemiaRoutes = Router();

glicemiaRoutes.get("/", listarGlicemias);
glicemiaRoutes.get("/resumo", obterResumoGlicemia);
glicemiaRoutes.get("/insulinas", listarInsulinas);
glicemiaRoutes.post("/", criarGlicemia);
glicemiaRoutes.post("/insulinas", criarInsulina);
glicemiaRoutes.get("/:id", buscarGlicemia);
glicemiaRoutes.patch("/:id", atualizarGlicemia);
glicemiaRoutes.delete("/:id", removerGlicemia);
