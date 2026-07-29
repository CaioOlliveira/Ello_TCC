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

const seteDiasEmMs = 7 * 24 * 60 * 60 * 1000;

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

    const existente = await getPool().query<Record<string, unknown>>(
      `
        select *
        from convites
        where idoso_id = $1
          and status = 'ativo'
          and (expira_em is null or expira_em > now())
        order by criado_em desc
        limit 1
      `,
      [input.idosoId],
    );

    if (existente.rows[0]) {
      return existente.rows[0];
    }

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
        expiraEm:
          input.expiraEm ?? new Date(Date.now() + seteDiasEmMs).toISOString(),
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
        where upper(codigo) = upper($1)
        limit 1
      `,
      [input.codigo],
    );
    const convite = result.rows[0];

    if (!convite) {
      throw new AppError(
        "CONVITE_NAO_ENCONTRADO",
        "Codigo de convite nao encontrado.",
        404,
      );
    }

    if (convite.status !== "ativo") {
      throw new AppError(
        "CONVITE_INDISPONIVEL",
        "Este convite ja foi utilizado ou revogado.",
        400,
      );
    }

    if (convite.expira_em && new Date(String(convite.expira_em)) < new Date()) {
      throw new AppError("CONVITE_EXPIRADO", "Este convite expirou.", 400);
    }

    const ficha = await getPool().query<{ criado_por_id: string }>(
      "select criado_por_id from fichas_idosos where id = $1 limit 1",
      [convite.idoso_id],
    );

    if (ficha.rows[0]?.criado_por_id === input.usadoPorId) {
      throw new AppError(
        "CONVITE_PROPRIO",
        "Voce ja e o responsavel por essa ficha.",
        400,
      );
    }

    const existente = await getPool().query<Record<string, unknown>>(
      `
        select *
        from membros_ficha
        where idoso_id = $1 and usuario_id = $2
        limit 1
      `,
      [convite.idoso_id, input.usadoPorId],
    );

    const membroExistente = existente.rows[0];

    if (membroExistente?.status === "ativo") {
      throw new AppError("JA_MEMBRO", "Voce ja tem acesso a essa ficha.", 409);
    }

    if (membroExistente?.status === "pendente") {
      throw new AppError(
        "SOLICITACAO_PENDENTE",
        "Voce ja solicitou acesso a essa ficha. Aguarde a aprovacao.",
        409,
      );
    }

    const membro = membroExistente
      ? await updateRow<Record<string, unknown>, Record<string, unknown>>(
          "membros_ficha",
          String(membroExistente.id),
          {
            funcao: convite.funcao_inicial,
            status: "pendente",
          },
          {
            funcao: "funcao",
            status: "status",
          },
          "MEMBRO_NAO_ENCONTRADO",
          "Membro não encontrado.",
        )
      : await insertRow<Record<string, unknown>, Record<string, unknown>>(
          "membros_ficha",
          {
            idosoId: convite.idoso_id,
            usuarioId: input.usadoPorId,
            funcao: convite.funcao_inicial,
            status: "pendente",
          },
          {
            idosoId: "idoso_id",
            usuarioId: "usuario_id",
            funcao: "funcao",
            status: "status",
          },
        );

    await updateRow<Record<string, unknown>, Record<string, unknown>>(
      table,
      String(convite.id),
      { usadoPorId: input.usadoPorId },
      fields,
      ...notFound,
    );

    await registrarHistorico({
      usuarioId: input.usadoPorId,
      idosoId: String(convite.idoso_id),
      acao: "solicitar_acesso",
      tipoEntidade: "membros_ficha",
      entidadeId: String(membro.id),
      dadosNovos: membro,
    });

    return { convite, membro, status: "pendente" as const };
  },
};
