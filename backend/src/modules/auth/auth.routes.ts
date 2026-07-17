import { Router } from "express";

import {
  cadastrar,
  cadastrarGoogle,
  login,
  loginGoogle,
  obterStatusAuth,
} from "./auth.controller.js";

export const authRoutes = Router();

authRoutes.get("/status", obterStatusAuth);
authRoutes.post("/login", login);
authRoutes.post("/google", loginGoogle);
authRoutes.post("/google/cadastro", cadastrarGoogle);
authRoutes.post("/cadastro", cadastrar);
