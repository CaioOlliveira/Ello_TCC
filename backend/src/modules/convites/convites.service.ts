import crypto from "node:crypto";

import { AppError } from "../../common/errors/app-error.js";
import { registrarHistorico } from "../../database/audit.js";
import { getPool } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  getRowById,
  insertRow,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AceitarConviteInput,
  AtualizarConviteInput,
  CriarConviteInput,
} from "./convites.schemas.js";

const table = "convites";
const notFound = ["CONVITE_NAO_ENCONTRADO", "Convite não encontrado."] as const;

const fields = {
  idosoId: "idoso_id",
  convidadoPorId: "convidado_por_id",
  codigo: "codigo",
  funcaoInicial: "funcao_inicial",
  expiraEm: "expira_em",
  usadoPorId: "usado_por_id",
  status: "status",
} as const;

const gerarCodigo = () => crypto.randomBytes(4).toString("hex").toUpperCase();

export const convitesService = {
  async listar(limit: number, offset: number) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      orderBy: "id desc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarConviteInput) {
    const convidadoPorId = await resolverUsuarioRegistroId(
      input.convidadoPorId,
    );
    const convite = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      table,
      {
        ...input,
        convidadoPorId,
        codigo: input.codigo ?? gerarCodigo(),
        status: input.status ?? "ativo",
      },
      fields,
    );

    await registrarHistorico({
      usuarioId: convidadoPorId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(convite.id),
      dadosNovos: convite,
    });

    return convite;
  },

  async atualizar(id: string, input: AtualizarConviteInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarConviteInput,
      Record<string, unknown>
    >(table, id, input, fields, ...notFound);

    await registrarHistorico({
      usuarioId: input.convidadoPorId,
      idosoId: String(atualizado.idoso_id ?? ""),
      acao: "atualizar",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
      dadosNovos: atualizado,
    });

    return atualizado;
  },

  async revogar(id: string, usuarioId?: string) {
    return this.atualizar(id, {
      status: "revogado",
      convidadoPorId: usuarioId,
    });
  },

  async aceitar(input: AceitarConviteInput) {
    const result = await getPool().query<Record<string, unknown>>(
      `
        select *
        from convites
        where codigo = $1
        limit 1
      `,
      [input.codigo],
    );
    const convite = result.rows[0];

    if (!convite) {
      throw new AppError(
        "CONVITE_NAO_ENCONTRADO",
        "Convite não encontrado.",
        404,
      );
    }

    if (convite.status !== "ativo") {
      throw new AppError(
        "CONVITE_INDISPONIVEL",
        "Convite não está ativo.",
        400,
      );
    }

    if (convite.expira_em && new Date(String(convite.expira_em)) < new Date()) {
      throw new AppError("CONVITE_EXPIRADO", "Convite expirado.", 400);
    }

    const membro = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      "membros_ficha",
      {
        idosoId: convite.idoso_id,
        usuarioId: input.usadoPorId,
        funcao: convite.funcao_inicial,
        status: "ativo",
      },
      {
        idosoId: "idoso_id",
        usuarioId: "usuario_id",
        funcao: "funcao",
        status: "status",
      },
    );

    const atualizado = await updateRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      table,
      String(convite.id),
      {
        usadoPorId: input.usadoPorId,
        status: "usado",
      },
      fields,
      ...notFound,
    );

    await registrarHistorico({
      usuarioId: input.usadoPorId,
      idosoId: String(convite.idoso_id),
      acao: "aceitar",
      tipoEntidade: table,
      entidadeId: String(convite.id),
      dadosAnteriores: convite,
      dadosNovos: atualizado,
    });

    return { convite: atualizado, membro };
  },
};
