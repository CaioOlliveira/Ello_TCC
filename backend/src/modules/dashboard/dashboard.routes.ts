import { Router } from "express";

import { obterDashboardIdoso } from "./dashboard.controller.js";

export const dashboardRoutes = Router();

dashboardRoutes.get("/idosos/:idosoId", obterDashboardIdoso);
