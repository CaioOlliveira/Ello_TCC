import { AppError } from "../../common/errors/app-error.js";
import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import {
  deleteRow,
  getRowById,
  insertRow,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarInsumoInput,
  CriarInsumoInput,
  CriarMovimentacaoInsumoInput,
} from "./insumos.schemas.js";

const table = "insumos";
const notFound = ["INSUMO_NAO_ENCONTRADO", "Insumo não encontrado."] as const;

const fields = {
  idosoId: "idoso_id",
  nome: "nome",
  tipoUnidade: "tipo_unidade",
  quantidadePorUnidade: "quantidade_por_unidade",
  quantidadeUnidades: "quantidade_unidades",
  alertaMinimoUnidades: "alerta_minimo_unidades",
  consumoMedioDiario: "consumo_medio_diario",
  dataValidade: "data_validade",
  observacoes: "observacoes",
} as const;

export const insumosService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "nome asc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarInsumoInput) {
    const insumo = await insertRow<CriarInsumoInput, Record<string, unknown>>(
      table,
      input,
      fields,
    );
    await registrarHistorico({
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(insumo.id),
      dadosNovos: insumo,
    });
    return insumo;
  },

  async atualizar(id: string, input: AtualizarInsumoInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarInsumoInput,
      Record<string, unknown>
    >(table, id, input, fields, ...notFound);
    await registrarHistorico({
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

  async listarMovimentacoes(insumoId: string) {
    const result = await getPool().query(
      `
        select *
        from historico_alteracoes
        where tipo_entidade = 'insumos'
          and entidade_id = $1
          and acao = 'movimentar_estoque'
        order by criado_em desc
      `,
      [insumoId],
    );
    return result.rows;
  },

  async movimentar(insumoId: string, input: CriarMovimentacaoInsumoInput) {
    if (isDatabaseEnabled) {
      const pool = getPool();
      const client = await pool.connect();

      try {
        await client.query("begin");

        const insumoResult = await client.query<{
          id: string;
          quantidade_unidades: string;
        }>(
          `
            select id, quantidade_unidades
            from insumos
            where id = $1
            for update
          `,
          [insumoId],
        );

        const insumo = insumoResult.rows[0];

        if (!insumo) {
          throw new AppError(...notFound, 404);
        }

        const quantidadeAtual = Number(insumo.quantidade_unidades);
        const novaQuantidade =
          input.tipo === "entrada"
            ? quantidadeAtual + input.quantidade
            : input.tipo === "saida"
              ? quantidadeAtual - input.quantidade
              : input.quantidade;

        const atualizadoResult = await client.query(
          `
            update insumos
            set quantidade_unidades = $1
            where id = $2
            returning
              id,
              idoso_id,
              quantidade_unidades as "quantidadeAtual",
              atualizado_em as "registradoEm"
          `,
          [novaQuantidade, insumoId],
        );

        await client.query("commit");

        const atualizado = atualizadoResult.rows[0];

        const movimentacao = {
          id: "movimentacao-insumo-ficticia",
          insumoId,
          tipo: input.tipo,
          quantidade: input.quantidade,
          motivo: input.motivo,
          observacoes: input.observacoes,
          quantidadeAnterior: quantidadeAtual,
          ...atualizado,
        };

        await registrarHistorico({
          usuarioId: input.usuarioId,
          idosoId: String(atualizado.idoso_id ?? ""),
          acao: "movimentar_estoque",
          tipoEntidade: table,
          entidadeId: insumoId,
          dadosAnteriores: { quantidade_unidades: quantidadeAtual },
          dadosNovos: movimentacao,
        });

        return movimentacao;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    }

    return {
      id: "movimentacao-insumo-1",
      insumoId,
      ...input,
      registradoEm: new Date().toISOString(),
    };
  },
};
