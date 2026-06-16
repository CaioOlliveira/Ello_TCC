import { Router } from "express";

import {
  atualizarMembro,
  buscarMembro,
  criarMembro,
  listarMembros,
  removerMembro,
} from "./membros.controller.js";

export const membrosRoutes = Router();

membrosRoutes.get("/", listarMembros);
membrosRoutes.post("/", criarMembro);
membrosRoutes.get("/:id", buscarMembro);
membrosRoutes.patch("/:id", atualizarMembro);
membrosRoutes.delete("/:id", removerMembro);
