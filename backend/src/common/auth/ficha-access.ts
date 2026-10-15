import { AppError } from "../errors/app-error.js";
import { getPool } from "../../database/pool.js";
import type { RequestHandler } from "express";
import {
  getAuthenticatedUserId,
  requireAuthenticatedUser,
} from "../middlewares/authenticated-user.js";
import { asyncHandler } from "../utils/async-handler.js";

export async function validarAcessoFicha(idosoId: string, usuarioId: string) {
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      idosoId,
    )
  ) {
    throw new AppError("FICHA_INVALIDA", "Ficha inválida.", 400);
  }
  const result = await getPool().query(
    `select 1 from fichas_idosos f
     where f.id = $1
       and (f.criado_por_id = $2 or exists (
         select 1 from membros_ficha m
         where m.idoso_id = f.id and m.usuario_id = $2 and m.status = 'ativo'
       )) limit 1`,
    [idosoId, usuarioId],
  );
  if (result.rowCount === 0) {
    throw new AppError(
      "ACESSO_FICHA_NEGADO",
      "Você não tem acesso a esta ficha.",
      403,
    );
  }
}

export async function validarAdministracaoFicha(
  idosoId: string,
  usuarioId: string,
) {
  const result = await getPool().query(
    `select 1 from fichas_idosos f
     where f.id = $1
       and (
         f.criado_por_id = $2
         or exists (
           select 1 from historico_alteracoes h
           where h.tipo_entidade = 'fichas_idosos' and h.acao = 'criar'
             and h.entidade_id::text = f.id::text and h.usuario_id = $2
         )
         or exists (
           select 1 from membros_ficha m
           where m.idoso_id = f.id and m.usuario_id = $2
             and m.status = 'ativo' and m.e_administrador = true
         )
       ) limit 1`,
    [idosoId, usuarioId],
  );
  if (result.rowCount === 0) {
    throw new AppError(
      "ADMINISTRACAO_FICHA_NEGADA",
      "Você não pode gerenciar os acessos desta ficha.",
      403,
    );
  }
}

export const requireFichaAccessFromQuery: RequestHandler[] = [
  requireAuthenticatedUser,
  asyncHandler(async (req, _res, next) => {
    const idosoId = req.query.idosoId;
    if (typeof idosoId !== "string" || !idosoId) {
      throw new AppError("FICHA_OBRIGATORIA", "Selecione uma ficha.", 400);
    }
    await validarAcessoFicha(idosoId, getAuthenticatedUserId(req));
    next();
  }),
];
