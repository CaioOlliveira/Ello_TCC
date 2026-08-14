import { Router } from "express";

import {
  aprovarMembro,
  atualizarMembro,
  buscarMembro,
  criarMembro,
  listarMembros,
  listarPendentes,
  listarParticipantes,
  negarMembro,
  registrarPresenca,
  removerMembro,
  revogarMembro,
} from "./membros.controller.js";

export const membrosRoutes = Router();

membrosRoutes.get("/", listarMembros);
membrosRoutes.post("/", criarMembro);
membrosRoutes.get("/participantes", listarParticipantes);
membrosRoutes.get("/pendentes", listarPendentes);
membrosRoutes.post("/presenca", registrarPresenca);
membrosRoutes.get("/:id", buscarMembro);
membrosRoutes.patch("/:id", atualizarMembro);
membrosRoutes.post("/:id/aprovar", aprovarMembro);
membrosRoutes.post("/:id/negar", negarMembro);
membrosRoutes.post("/:id/revogar", revogarMembro);
membrosRoutes.delete("/:id", removerMembro);
