import { Router } from "express";

import { obterStatusAuth } from "./auth.controller.js";

export const authRoutes = Router();

authRoutes.get("/status", obterStatusAuth);
