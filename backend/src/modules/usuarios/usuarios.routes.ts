import { Router } from "express";

import {
  atualizarUsuario,
  buscarUsuario,
  criarUsuario,
  listarUsuarios,
  removerUsuario,
} from "./usuarios.controller.js";

export const usuariosRoutes = Router();

usuariosRoutes.get("/", listarUsuarios);
usuariosRoutes.post("/", criarUsuario);
usuariosRoutes.get("/:id", buscarUsuario);
usuariosRoutes.patch("/:id", atualizarUsuario);
usuariosRoutes.delete("/:id", removerUsuario);
