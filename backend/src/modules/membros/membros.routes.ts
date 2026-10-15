import { Router } from "express";
import { requireAuthenticatedUser } from "../../common/middlewares/authenticated-user.js";

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
membrosRoutes.get("/pendentes", requireAuthenticatedUser, listarPendentes);
membrosRoutes.post("/presenca", registrarPresenca);
membrosRoutes.get("/:id", buscarMembro);
membrosRoutes.patch("/:id", atualizarMembro);
membrosRoutes.post("/:id/aprovar", requireAuthenticatedUser, aprovarMembro);
membrosRoutes.post("/:id/negar", requireAuthenticatedUser, negarMembro);
membrosRoutes.post("/:id/revogar", revogarMembro);
membrosRoutes.delete("/:id", removerMembro);
