import { registrarHistorico } from "../../database/audit.js";
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
  status: "status",
} as const;

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

  async criar(input: CriarMembroInput) {
    const membro = await insertRow<CriarMembroInput, Record<string, unknown>>(
      table,
      {
        ...input,
        podeEditar: input.podeEditar ?? false,
        podeConvidar: input.podeConvidar ?? false,
        podeGerenciarMedicacoes: input.podeGerenciarMedicacoes ?? false,
        podeGerarRelatorios: input.podeGerarRelatorios ?? false,
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
