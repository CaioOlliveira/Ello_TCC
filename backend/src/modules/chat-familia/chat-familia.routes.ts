import { Router } from "express";

import {
  apagarConversaFamilia,
  criarMensagemFamilia,
  listarConversasFamilia,
  listarMensagensFamilia,
} from "./chat-familia.controller.js";

export const chatFamiliaRoutes = Router();

chatFamiliaRoutes.get("/conversas", listarConversasFamilia);
chatFamiliaRoutes.delete("/conversas", apagarConversaFamilia);
chatFamiliaRoutes.get("/mensagens", listarMensagensFamilia);
chatFamiliaRoutes.post("/mensagens", criarMensagemFamilia);
