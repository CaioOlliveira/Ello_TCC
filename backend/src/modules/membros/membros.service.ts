import { AppError } from "../../common/errors/app-error.js";
import { registrarHistorico } from "../../database/audit.js";
import { getPool } from "../../database/pool.js";
import {
  deleteRow,
  getRowById,
  insertRow,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarMembroInput,
  CriarMembroInput,
} from "./membros.schemas.js";

const table = "membros_ficha";
const notFound = ["MEMBRO_NAO_ENCONTRADO", "Membro não encontrado."] as const;

const fields = {
  idosoId: "idoso_id",
  usuarioId: "usuario_id",
  funcao: "funcao",
  relacao: "relacao",
  podeEditar: "pode_editar",
  podeConvidar: "pode_convidar",
  podeGerenciarMedicacoes: "pode_gerenciar_medicacoes",
  podeGerarRelatorios: "pode_gerar_relatorios",
  eAdministrador: "e_administrador",
  permissoes: "permissoes",
  status: "status",
} as const;

const defaultPermissoes = (monitoramentos: string[]) => ({
  visualizar: ["Ficha", ...monitoramentos],
  editar: [],
});

export const membrosService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "id desc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async buscarComUsuario(id: string) {
    const result = await getPool().query<Record<string, unknown>>(
      `
        select
          mf.*,
          u.nome as usuario_nome,
          u.url_foto as usuario_foto,
          u.telefone as usuario_telefone,
          u.email as usuario_email
        from membros_ficha mf
        join usuarios u on u.id = mf.usuario_id
        where mf.id = $1
        limit 1
      `,
      [id],
    );

    const membro = result.rows[0];
    if (!membro) {
      throw new AppError("MEMBRO_NAO_ENCONTRADO", "Membro não encontrado.", 404);
    }
    return membro;
  },

  async listarParticipantes(idosoId: string) {
    const ficha = await getPool().query<Record<string, unknown>>(
      `
        select f.criado_por_id, u.nome, u.url_foto, u.telefone
        from fichas_idosos f
        join usuarios u on u.id = f.criado_por_id
        where f.id = $1
        limit 1
      `,
      [idosoId],
    );

    const criador = ficha.rows[0];
    const responsavel = criador
      ? [
          {
            id: null,
            idoso_id: idosoId,
            usuario_id: criador.criado_por_id,
            usuario_nome: criador.nome,
            usuario_foto: criador.url_foto,
            usuario_telefone: criador.telefone,
            funcao: null,
            relacao: null,
            e_administrador: true,
            e_criador: true,
            permissoes: { visualizar: [], editar: [] },
            status: "ativo",
          },
        ]
      : [];

    const membros = await getPool().query<Record<string, unknown>>(
      `
        select
          mf.id,
          mf.idoso_id,
          mf.usuario_id,
          mf.funcao,
          mf.relacao,
          mf.e_administrador,
          mf.permissoes,
          mf.status,
          mf.criado_em,
          u.nome as usuario_nome,
          u.url_foto as usuario_foto,
          u.telefone as usuario_telefone
        from membros_ficha mf
        join usuarios u on u.id = mf.usuario_id
        where mf.idoso_id = $1
          and mf.status = 'ativo'
          and mf.usuario_id != $2
        order by mf.criado_em asc
      `,
      [idosoId, criador?.criado_por_id ?? "00000000-0000-0000-0000-000000000000"],
    );

    return [
      ...responsavel,
      ...membros.rows.map((row) => ({ ...row, e_criador: false })),
    ];
  },

  async listarPendentes(idosoId: string) {
    const result = await getPool().query<Record<string, unknown>>(
      `
        select
          mf.id,
          mf.idoso_id,
          mf.usuario_id,
          mf.funcao,
          mf.criado_em,
          u.nome as usuario_nome,
          u.url_foto as usuario_foto
        from membros_ficha mf
        join usuarios u on u.id = mf.usuario_id
        where mf.idoso_id = $1
          and mf.status = 'pendente'
        order by mf.criado_em asc
      `,
      [idosoId],
    );
    return result.rows;
  },

  async criar(input: CriarMembroInput) {
    const membro = await insertRow<CriarMembroInput, Record<string, unknown>>(
      table,
      {
        ...input,
        podeEditar: input.podeEditar ?? false,
        podeConvidar: input.podeConvidar ?? false,
        podeGerenciarMedicacoes: input.podeGerenciarMedicacoes ?? false,
        podeGerarRelatorios: input.podeGerarRelatorios ?? false,
        eAdministrador: input.eAdministrador ?? false,
        status: input.status ?? "ativo",
      },
      fields,
    );
    await registrarHistorico({
      usuarioId: input.usuarioId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(membro.id),
      dadosNovos: membro,
    });
    return membro;
  },

  async atualizar(id: string, input: AtualizarMembroInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarMembroInput,
      Record<string, unknown>
    >(table, id, input, fields, ...notFound);
    await registrarHistorico({
      usuarioId: input.usuarioId,
      idosoId: String(atualizado.idoso_id ?? ""),
      acao: "atualizar",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
      dadosNovos: atualizado,
    });
    return atualizado;
  },

  async aprovar(id: string, aprovadoPorId?: string) {
    const membro = await this.buscarPorId(id);
    if (membro.status !== "pendente") {
      throw new AppError(
        "SOLICITACAO_INDISPONIVEL",
        "Esta solicitação já foi respondida.",
        400,
      );
    }

    const ficha = await getPool().query<{ monitoramentos: string[] }>(
      "select monitoramentos from fichas_idosos where id = $1 limit 1",
      [membro.idoso_id],
    );
    const monitoramentos = ficha.rows[0]?.monitoramentos ?? [];

    const atualizado = await updateRow<
      AtualizarMembroInput,
      Record<string, unknown>
    >(
      table,
      id,
      {
        status: "ativo",
        permissoes: defaultPermissoes(monitoramentos),
      },
      fields,
      ...notFound,
    );

    await registrarHistorico({
      usuarioId: aprovadoPorId,
      idosoId: String(membro.idoso_id ?? ""),
      acao: "aprovar",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: membro,
      dadosNovos: atualizado,
    });

    return atualizado;
  },

  async negar(id: string, negadoPorId?: string) {
    const membro = await this.buscarPorId(id);
    if (membro.status !== "pendente") {
      throw new AppError(
        "SOLICITACAO_INDISPONIVEL",
        "Esta solicitação já foi respondida.",
        400,
      );
    }

    const atualizado = await updateRow<
      AtualizarMembroInput,
      Record<string, unknown>
    >(table, id, { status: "recusado" }, fields, ...notFound);

    await registrarHistorico({
      usuarioId: negadoPorId,
      idosoId: String(membro.idoso_id ?? ""),
      acao: "negar",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: membro,
      dadosNovos: atualizado,
    });

    return atualizado;
  },

  async revogar(id: string, revogadoPorId?: string) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarMembroInput,
      Record<string, unknown>
    >(table, id, { status: "revogado" }, fields, ...notFound);

    await registrarHistorico({
      usuarioId: revogadoPorId,
      idosoId: String(anterior.idoso_id ?? ""),
      acao: "revogar",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
      dadosNovos: atualizado,
    });

    return atualizado;
  },

  async remover(id: string) {
    const anterior = await this.buscarPorId(id);
    await deleteRow(table, id, ...notFound);
    await registrarHistorico({
      idosoId: String(anterior.idoso_id ?? ""),
      acao: "remover",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
    });
  },
};
