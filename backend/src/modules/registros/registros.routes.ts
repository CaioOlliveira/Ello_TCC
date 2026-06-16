import { Router } from "express";

import {
  criarHidratacao,
  criarHumor,
  criarOxigenacao,
  criarPressao,
  criarSono,
  listarHidratacoes,
  listarHumores,
  listarOxigenacoes,
  listarPressoes,
  listarSonos,
} from "./registros.controller.js";

export const registrosRoutes = Router();

registrosRoutes.get("/hidratacoes", listarHidratacoes);
registrosRoutes.post("/hidratacoes", criarHidratacao);
registrosRoutes.get("/humores", listarHumores);
registrosRoutes.post("/humores", criarHumor);
registrosRoutes.get("/sonos", listarSonos);
registrosRoutes.post("/sonos", criarSono);
registrosRoutes.get("/oxigenacoes", listarOxigenacoes);
registrosRoutes.post("/oxigenacoes", criarOxigenacao);
registrosRoutes.get("/pressoes", listarPressoes);
registrosRoutes.post("/pressoes", criarPressao);
