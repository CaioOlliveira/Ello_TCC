import { Router } from "express";
import { requireAuthenticatedUser } from "../../common/middlewares/authenticated-user.js";

import {
  aceitarConvite,
  atualizarConvite,
  buscarConvite,
  criarConvite,
  listarConvites,
  revogarConvite,
} from "./convites.controller.js";

export const convitesRoutes = Router();

convitesRoutes.get("/", listarConvites);
convitesRoutes.post("/", criarConvite);
convitesRoutes.post("/aceitar", requireAuthenticatedUser, aceitarConvite);
convitesRoutes.get("/:id", buscarConvite);
convitesRoutes.patch("/:id", atualizarConvite);
convitesRoutes.post("/:id/revogar", revogarConvite);
