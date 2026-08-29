import type { Request, RequestHandler } from "express";

import { AppError } from "../errors/app-error.js";
import { validarTokenSessao } from "../auth/session-token.js";

type AuthenticatedRequest = Request & { authenticatedUserId?: string };

export const requireAuthenticatedUser: RequestHandler = (req, _res, next) => {
  const authorization = req.header("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  const usuarioId = token ? validarTokenSessao(token) : null;

  if (!usuarioId) {
    next(
      new AppError(
        "SESSAO_INVALIDA",
        "Sua sessao expirou. Entre novamente para continuar.",
        401,
      ),
    );
    return;
  }

  (req as AuthenticatedRequest).authenticatedUserId = usuarioId;
  next();
};

export const getAuthenticatedUserId = (req: Request) => {
  const usuarioId = (req as AuthenticatedRequest).authenticatedUserId;
  if (!usuarioId) {
    throw new AppError(
      "SESSAO_INVALIDA",
      "Sua sessao expirou. Entre novamente para continuar.",
      401,
    );
  }
  return usuarioId;
};
