import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import { deleteRow, getRowById, listRows } from "../../database/simple-crud.js";
import type { CriarRefeicaoInput } from "./alimentacao.schemas.js";

const table = "registros_alimentacao";
const notFound = [
  "REFEICAO_NAO_ENCONTRADA",
  "Refeição não encontrada.",
] as const;

type RefeicaoRow = Record<string, unknown> & {
  idoso_id?: string;
};

export const alimentacaoService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "alimentou_em desc",
    });
  },

  async buscarPorId(id: string) {
    const refeicao = await getRowById<RefeicaoRow>(table, id, ...notFound);
    const itens = await getPool().query(
      "select * from itens_refeicao where refeicao_id = $1 order by descricao",
      [id],
    );
    return { ...refeicao, itens: itens.rows } as RefeicaoRow & {
      itens: Record<string, unknown>[];
    };
  },

  async criar(input: CriarRefeicaoInput) {
    if (isDatabaseEnabled) {
      const pool = getPool();
      const client = await pool.connect();

      try {
        await client.query("begin");

        const registradoPorId = await resolverUsuarioRegistroId(
          input.registradoPorId,
        );

        const refeicaoResult = await client.query(
          `
            insert into registros_alimentacao (
              idoso_id,
              tipo_refeicao,
              alimentou_em,
              aceitacao,
              observacoes,
              registrado_por_id
            )
            values ($1, $2, $3, $4, $5, $6)
            returning
              id,
              idoso_id as "idosoId",
              tipo_refeicao as "tipoRefeicao",
              alimentou_em as "registradoEm",
              aceitacao,
              observacoes,
              registrado_por_id as "registradoPorId"
          `,
          [
            input.idosoId,
            input.tipoRefeicao,
            input.registradoEm,
            input.aceitacao,
            input.observacoes ?? null,
            registradoPorId,
          ],
        );

        const refeicao = refeicaoResult.rows[0];

        for (const alimento of input.alimentos) {
          await client.query(
            `
              insert into itens_refeicao (refeicao_id, descricao)
              values ($1, $2)
            `,
            [refeicao.id, alimento],
          );
        }

        await client.query("commit");

        const dados = {
          ...refeicao,
          alimentos: input.alimentos,
        };

        await registrarHistorico({
          usuarioId: registradoPorId,
          idosoId: input.idosoId,
          acao: "criar",
          tipoEntidade: table,
          entidadeId: String(refeicao.id),
          dadosNovos: dados,
        });

        return dados;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    }

    return {
      id: "refeicao-1",
      ...input,
    };
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
