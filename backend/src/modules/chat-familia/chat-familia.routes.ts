import { Router } from "express";

import {
  criarMensagemFamilia,
  listarMensagensFamilia,
} from "./chat-familia.controller.js";

export const chatFamiliaRoutes = Router();

chatFamiliaRoutes.get("/mensagens", listarMensagensFamilia);
chatFamiliaRoutes.post("/mensagens", criarMensagemFamilia);
