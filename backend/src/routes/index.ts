import { Router } from "express";

import { agendaRoutes } from "../modules/agenda/agenda.routes.js";
import { alimentacaoRoutes } from "../modules/alimentacao/alimentacao.routes.js";
import { authRoutes } from "../modules/auth/auth.routes.js";
import { chatFamiliaRoutes } from "../modules/chat-familia/chat-familia.routes.js";
import { convitesRoutes } from "../modules/convites/convites.routes.js";
import { dashboardRoutes } from "../modules/dashboard/dashboard.routes.js";
import { equipamentosRoutes } from "../modules/equipamentos/equipamentos.routes.js";
import { glicemiaRoutes } from "../modules/glicemia/glicemia.routes.js";
import { historicoRoutes } from "../modules/historico/historico.routes.js";
import { iaRoutes } from "../modules/ia/ia.routes.js";
import { idososRoutes } from "../modules/idosos/idosos.routes.js";
import { insumosRoutes } from "../modules/insumos/insumos.routes.js";
import { medicamentosRoutes } from "../modules/medicamentos/medicamentos.routes.js";
import { membrosRoutes } from "../modules/membros/membros.routes.js";
import { notificacoesRoutes } from "../modules/notificacoes/notificacoes.routes.js";
import { oxigenacaoRoutes } from "../modules/oxigenacao/oxigenacao.routes.js";
import { pressaoRoutes } from "../modules/pressao/pressao.routes.js";
import { registrosRoutes } from "../modules/registros/registros.routes.js";
import { relatoriosRoutes } from "../modules/relatorios/relatorios.routes.js";
import { temperaturaRoutes } from "../modules/temperatura/temperatura.routes.js";
import { usuariosRoutes } from "../modules/usuarios/usuarios.routes.js";

export const routes = Router();

routes.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    service: "ello-api",
    timestamp: new Date().toISOString(),
  });
});

routes.use("/auth", authRoutes);
routes.use("/chat-familia", chatFamiliaRoutes);
routes.use("/usuarios", usuariosRoutes);
routes.use("/convites", convitesRoutes);
routes.use("/dashboard", dashboardRoutes);
routes.use("/idosos", idososRoutes);
routes.use("/glicemias", glicemiaRoutes);
routes.use("/historico", historicoRoutes);
routes.use("/ia", iaRoutes);
routes.use("/refeicoes", alimentacaoRoutes);
routes.use("/medicamentos", medicamentosRoutes);
routes.use("/membros", membrosRoutes);
routes.use("/agenda", agendaRoutes);
routes.use("/equipamentos", equipamentosRoutes);
routes.use("/insumos", insumosRoutes);
routes.use("/notificacoes", notificacoesRoutes);
routes.use("/oxigenacao", oxigenacaoRoutes);
routes.use("/pressao", pressaoRoutes);
routes.use("/registros", registrosRoutes);
routes.use("/relatorios", relatoriosRoutes);
routes.use("/temperatura", temperaturaRoutes);
