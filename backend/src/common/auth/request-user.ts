import { AsyncLocalStorage } from "node:async_hooks";
import type { RequestHandler } from "express";
import { AppError } from "../errors/app-error.js";
import { validarTokenSessao } from "./session-token.js";

const requestUser = new AsyncLocalStorage<string | null>();

export const attachRequestUser: RequestHandler = (req, _res, next) => {
  const authorization = req.header("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  const usuarioId = token ? validarTokenSessao(token) : null;
  if (authorization && !usuarioId) {
    next(
      new AppError(
        "SESSAO_INVALIDA",
        "Sua sessão expirou. Entre novamente para continuar.",
        401,
      ),
    );
    return;
  }
  requestUser.run(usuarioId, next);
};

export const getRequestUserId = () => requestUser.getStore() ?? null;
