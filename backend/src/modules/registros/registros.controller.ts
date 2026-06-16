import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/utils/async-handler.js";
import { getPagination } from "../../common/utils/request-query.js";
import {
  hidratacaoSchema,
  humorSchema,
  oxigenacaoSchema,
  pressaoSchema,
  sonoSchema,
} from "./registros.schemas.js";
import { registrosService } from "./registros.service.js";

const criarListagem = (
  tipo: Parameters<typeof registrosService.listar>[0],
): RequestHandler =>
  asyncHandler(async (req, res) => {
    const { limite, offset, pagina } = getPagination(req.query);
    const idosoId =
      typeof req.query.idosoId === "string" ? req.query.idosoId : undefined;
    const { dados, total } = await registrosService.listar(
      tipo,
      limite,
      offset,
      idosoId,
    );
    res.json({ dados, meta: { total, pagina, limite } });
  });

const criarCadastro = (
  tipo: Parameters<typeof registrosService.criar>[0],
  schema:
    | typeof hidratacaoSchema
    | typeof humorSchema
    | typeof sonoSchema
    | typeof oxigenacaoSchema
    | typeof pressaoSchema,
): RequestHandler =>
  asyncHandler(async (req, res) => {
    const input = schema.parse(req.body);
    res.status(201).json({ dados: await registrosService.criar(tipo, input) });
  });

export const listarHidratacoes = criarListagem("hidratacao");
export const criarHidratacao = criarCadastro("hidratacao", hidratacaoSchema);
export const listarHumores = criarListagem("humor");
export const criarHumor = criarCadastro("humor", humorSchema);
export const listarSonos = criarListagem("sono");
export const criarSono = criarCadastro("sono", sonoSchema);
export const listarOxigenacoes = criarListagem("oxigenacao");
export const criarOxigenacao = criarCadastro("oxigenacao", oxigenacaoSchema);
export const listarPressoes = criarListagem("pressao");
export const criarPressao = criarCadastro("pressao", pressaoSchema);
