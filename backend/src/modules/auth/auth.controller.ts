import type { RequestHandler } from "express";

import { authService } from "./auth.service.js";

export const obterStatusAuth: RequestHandler = (_req, res) => {
  res.json({ dados: authService.status() });
};
