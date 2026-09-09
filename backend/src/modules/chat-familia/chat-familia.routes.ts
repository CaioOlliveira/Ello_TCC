import { Router } from "express";

import { requireAuthenticatedUser } from "../../common/middlewares/authenticated-user.js";
import {
  apagarConversaFamilia,
  buscarFotoContatoChat,
  criarMensagemFamilia,
  listarConversasFamilia,
  listarMensagensFamilia,
  limparConversaFamilia,
  marcarMensagensFamiliaComoLidas,
  registrarDispositivoPushChat,
  registrarPresencaChat,
} from "./chat-familia.controller.js";

export const chatFamiliaRoutes = Router();

chatFamiliaRoutes.use(requireAuthenticatedUser);
chatFamiliaRoutes.get("/conversas", listarConversasFamilia);
chatFamiliaRoutes.delete("/conversas", apagarConversaFamilia);
chatFamiliaRoutes.post("/conversas/limpar", limparConversaFamilia);
chatFamiliaRoutes.get("/contatos/:contatoId/foto", buscarFotoContatoChat);
chatFamiliaRoutes.get("/mensagens", listarMensagensFamilia);
chatFamiliaRoutes.post("/mensagens", criarMensagemFamilia);
chatFamiliaRoutes.post("/mensagens/lidas", marcarMensagensFamiliaComoLidas);
chatFamiliaRoutes.post("/dispositivos", registrarDispositivoPushChat);
chatFamiliaRoutes.post("/presenca", registrarPresencaChat);
