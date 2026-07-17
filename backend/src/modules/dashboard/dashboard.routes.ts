import { Router } from "express";

import {
  obterDashboardIdoso,
  obterDicaDashboardIdoso,
} from "./dashboard.controller.js";

export const dashboardRoutes = Router();

dashboardRoutes.get("/idosos/:idosoId", obterDashboardIdoso);
dashboardRoutes.get("/idosos/:idosoId/dica", obterDicaDashboardIdoso);
