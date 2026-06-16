import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import {
  idParamSchema,
  getPagination,
} from "../../common/utils/request-query.js";
import {
  atualizarUsuarioSchema,
  criarUsuarioSchema,
} from "./usuarios.schemas.js";
import { usuariosService } from "./usuarios.service.js";

export const listarUsuarios: RequestHandler = asyncHandler(async (req, res) => {
  const { limite, offset, pagina } = getPagination(req.query);
  const { dados, total } = await usuariosService.listar(limite, offset);
  res.json({ dados, meta: { total, pagina, limite } });
});

export const buscarUsuario: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.json({ dados: await usuariosService.buscarPorId(id) });
});

export const criarUsuario: RequestHandler = asyncHandler(async (req, res) => {
  const input = criarUsuarioSchema.parse(req.body);
  res.status(201).json({ dados: await usuariosService.criar(input) });
});

export const atualizarUsuario: RequestHandler = asyncHandler(
  async (req, res) => {
    const { id } = idParamSchema.parse(req.params);
    const input = atualizarUsuarioSchema.parse(req.body);
    res.json({ dados: await usuariosService.atualizar(id, input) });
  },
);

export const removerUsuario: RequestHandler = asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  await usuariosService.remover(id);
  res.status(204).send();
});
