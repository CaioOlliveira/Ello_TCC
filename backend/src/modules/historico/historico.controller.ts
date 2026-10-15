import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import { listarHistoricoQuerySchema } from "./historico.schemas.js";
import { historicoService } from "./historico.service.js";
import { getAuthenticatedUserId } from "../../common/middlewares/authenticated-user.js";
import { validarAcessoFicha } from "../../common/auth/ficha-access.js";

export const listarHistorico: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = listarHistoricoQuerySchema.parse(req.query);
    await validarAcessoFicha(input.idosoId, getAuthenticatedUserId(req));
    const dados = await historicoService.listar(input);
    res.json({ dados, meta: { total: dados.length } });
  },
);
