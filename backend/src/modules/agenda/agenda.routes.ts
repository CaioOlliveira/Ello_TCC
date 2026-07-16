import { Router } from "express";

import {
  atualizarCompromisso,
  atualizarOcorrenciaCompromisso,
  buscarCompromisso,
  criarCompromisso,
  listarHistoricoAgenda,
  listarCompromissos,
  removerCompromisso,
} from "./agenda.controller.js";

export const agendaRoutes = Router();

agendaRoutes.get("/", listarCompromissos);
agendaRoutes.get("/historico", listarHistoricoAgenda);
agendaRoutes.post("/", criarCompromisso);
agendaRoutes.get("/:id", buscarCompromisso);
agendaRoutes.patch("/:id/ocorrencias", atualizarOcorrenciaCompromisso);
agendaRoutes.patch("/:id", atualizarCompromisso);
agendaRoutes.delete("/:id", removerCompromisso);
