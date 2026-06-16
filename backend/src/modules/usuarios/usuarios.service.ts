import { registrarHistorico } from "../../database/audit.js";
import {
  deleteRow,
  getRowById,
  insertRow,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarUsuarioInput,
  CriarUsuarioInput,
} from "./usuarios.schemas.js";

const table = "usuarios";
const notFound = ["USUARIO_NAO_ENCONTRADO", "Usuário não encontrado."] as const;

const fields = {
  nome: "nome",
  email: "email",
  telefone: "telefone",
  urlFoto: "url_foto",
  tipoUsuario: "tipo_usuario",
  senha: "senha",
} as const;

const removerSenha = <T extends { senha?: string }>(
  usuario: T,
): Omit<T, "senha"> => {
  const { senha: _senha, ...restante } = usuario;
  return restante;
};

export const usuariosService = {
  async listar(limit: number, offset: number) {
    const { dados, total } = await listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      orderBy: "criado_em desc",
    });

    return {
      dados: dados.map(removerSenha),
      total,
    };
  },

  async buscarPorId(id: string) {
    const usuario = await getRowById<
      Record<string, unknown> & { senha?: string }
    >(table, id, ...notFound);
    return removerSenha(usuario);
  },

  async criar(input: CriarUsuarioInput) {
    const usuario = await insertRow<CriarUsuarioInput, Record<string, unknown>>(
      table,
      {
        ...input,
        senha: input.senha ?? "gerenciada-pelo-supabase-auth",
      },
      fields,
    );

    await registrarHistorico({
      usuarioId: String(usuario.id),
      acao: "criar",
      tipoEntidade: "usuarios",
      entidadeId: String(usuario.id),
      dadosNovos: removerSenha(usuario),
    });

    return removerSenha(usuario);
  },

  async atualizar(id: string, input: AtualizarUsuarioInput) {
    const anterior = await this.buscarPorId(id);
    const usuario = await updateRow<
      AtualizarUsuarioInput,
      Record<string, unknown> & { senha?: string }
    >(table, id, input, fields, ...notFound);

    await registrarHistorico({
      usuarioId: id,
      acao: "atualizar",
      tipoEntidade: "usuarios",
      entidadeId: id,
      dadosAnteriores: anterior,
      dadosNovos: removerSenha(usuario),
    });

    return removerSenha(usuario);
  },

  async remover(id: string) {
    const anterior = await this.buscarPorId(id);
    await deleteRow(table, id, ...notFound);
    await registrarHistorico({
      usuarioId: id,
      acao: "remover",
      tipoEntidade: "usuarios",
      entidadeId: id,
      dadosAnteriores: anterior,
    });
  },
};
