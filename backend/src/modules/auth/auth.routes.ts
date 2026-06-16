import { Router } from "express";

import { cadastrar, login, obterStatusAuth } from "./auth.controller.js";

export const authRoutes = Router();

authRoutes.get("/status", obterStatusAuth);
authRoutes.post("/login", login);
authRoutes.post("/cadastro", cadastrar);
