import type { RequestHandler } from "express";
import { z } from "zod";

import { asyncHandler } from "../../common/utils/async-handler.js";
import { dashboardService } from "./dashboard.service.js";

const paramsSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
});

export const obterDashboardIdoso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId } = paramsSchema.parse(req.params);
    res.json({ dados: await dashboardService.obterResumo(idosoId) });
  },
);

export const obterDicaDashboardIdoso: RequestHandler = asyncHandler(
  async (req, res) => {
    const { idosoId } = paramsSchema.parse(req.params);
    res.json({ dados: await dashboardService.obterDicaDoDia(idosoId) });
  },
);
