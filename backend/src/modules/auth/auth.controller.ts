import type { RequestHandler } from "express";

import { authService } from "./auth.service.js";
import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  cadastroSchema,
  googleCadastroSchema,
  googleLoginSchema,
  loginSchema,
} from "./auth.schemas.js";

export const obterStatusAuth: RequestHandler = (_req, res) => {
  res.json({ dados: authService.status() });
};

export const login: RequestHandler = asyncHandler(async (req, res) => {
  const input = loginSchema.parse(req.body);
  res.json({ dados: await authService.login(input) });
});

export const cadastrar: RequestHandler = asyncHandler(async (req, res) => {
  const input = cadastroSchema.parse(req.body);
  res.status(201).json({ dados: await authService.cadastrar(input) });
});

export const loginGoogle: RequestHandler = asyncHandler(async (req, res) => {
  const input = googleLoginSchema.parse(req.body);
  res.json({ dados: await authService.loginGoogle(input) });
});

export const cadastrarGoogle: RequestHandler = asyncHandler(
  async (req, res) => {
    const input = googleCadastroSchema.parse(req.body);
    res.status(201).json({ dados: await authService.cadastrarGoogle(input) });
  },
);
