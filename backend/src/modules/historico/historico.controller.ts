import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import { listarHistoricoQuerySchema } from "./historico.schemas.js";
import { historicoService } from "./historico.service.js";

export const listarHistorico: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = listarHistoricoQuerySchema.parse(req.query);
    const dados = await historicoService.listar(input);
    res.json({ dados, meta: { total: dados.length } });
  },
);
