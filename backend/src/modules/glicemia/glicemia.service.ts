import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  deleteRow,
  getRowById,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarGlicemiaInput,
  CriarGlicemiaInput,
} from "./glicemia.schemas.js";

const table = "registros_glicemia";
const notFound = [
  "GLICEMIA_NAO_ENCONTRADA",
  "Registro de glicemia não encontrado.",
] as const;

const fields = {
  idosoId: "idoso_id",
  valor: "valor_mg_dl",
  contexto: "contexto_medicao",
  medidoEm: "medido_em",
  observacoes: "observacoes",
  sintomas: "sintomas",
  registradoPorId: "registrado_por_id",
} as const;

export const glicemiaService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "medido_em desc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarGlicemiaInput) {
    if (isDatabaseEnabled) {
      const registradoPorId = await resolverUsuarioRegistroId(
        input.registradoPorId,
      );

      const result = await getPool().query(
        `
          insert into registros_glicemia (
            idoso_id,
            valor_mg_dl,
            contexto_medicao,
            medido_em,
            observacoes,
            sintomas,
            registrado_por_id
          )
          values ($1, $2, $3, $4, $5, $6, $7)
          returning
            id,
            idoso_id as "idosoId",
            valor_mg_dl as valor,
            contexto_medicao as contexto,
            medido_em as "medidoEm",
            observacoes,
            sintomas,
            registrado_por_id as "registradoPorId"
        `,
        [
          input.idosoId,
          input.valor,
          input.contexto,
          input.medidoEm,
          input.observacoes ?? null,
          input.sintomas ?? null,
          registradoPorId,
        ],
      );

      const glicemia = result.rows[0];
      await registrarHistorico({
        usuarioId: registradoPorId,
        idosoId: input.idosoId,
        acao: "criar",
        tipoEntidade: table,
        entidadeId: String(glicemia.id),
        dadosNovos: glicemia,
      });

      return glicemia;
    }

    return {
      id: "glicemia-1",
      ...input,
    };
  },

  async atualizar(id: string, input: AtualizarGlicemiaInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarGlicemiaInput,
      Record<string, unknown>
    >(table, id, input, fields, ...notFound);
    await registrarHistorico({
      usuarioId: input.registradoPorId,
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
