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
type FiltroInsumos = "todos" | "acabando" | "vencendo" | "vencidos";
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
  diasAlertaValidade: "dias_alerta_validade",
  fotoUrl: "foto_url",
  localArmazenamento: "local_armazenamento",
  frequenciaUso: "frequencia_uso",
  observacoes: "observacoes",
} as const;

export const insumosService = {
  async listar(
    limit: number,
    offset: number,
    idosoId?: string,
    filtro: FiltroInsumos = "todos",
  ) {
    if (isDatabaseEnabled) {
      await aplicarConsumoAutomatico(idosoId);
    }

    const clauses: string[] = [];
    const params: unknown[] = [];

    if (idosoId) {
      params.push(idosoId);
      clauses.push(`idoso_id = $${params.length}`);
    }

    if (filtro === "acabando") {
      clauses.push(
        "alerta_minimo_unidades is not null and quantidade_unidades <= alerta_minimo_unidades",
      );
    } else if (filtro === "vencidos") {
      clauses.push("data_validade is not null and data_validade < current_date");
    } else if (filtro === "vencendo") {
      clauses.push(
        "data_validade is not null and data_validade >= current_date and data_validade <= current_date + dias_alerta_validade",
      );
    }

    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: clauses.length > 0 ? clauses.join(" and ") : undefined,
      params,
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
    if (
      isDatabaseEnabled &&
      (input.frequenciaUso !== undefined ||
        input.consumoMedioDiario !== undefined)
    ) {
      await getPool().query(
        "update insumos set ultimo_consumo_em = now() where id = $1",
        [id],
      );
    }
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

        if (novaQuantidade < 0) {
          throw new AppError(
            "ESTOQUE_INSUFICIENTE",
            "A movimentacao nao pode deixar o estoque negativo.",
            400,
          );
        }

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

async function aplicarConsumoAutomatico(idosoId?: string) {
  const params: unknown[] = idosoId ? [idosoId] : [];
  const idosoClause = idosoId ? "and idoso_id = $1" : "";

  await getPool().query(
    `
      update insumos as i
      set
        quantidade_unidades = greatest(
          0,
          i.quantidade_unidades -
            (
              i.consumo_medio_diario *
              floor(
                extract(epoch from (now() - i.ultimo_consumo_em)) /
                (
                  case
                    when i.frequencia_uso = 'Semanal' then 7
                    when i.frequencia_uso = 'Mensal' then 30
                    else 1
                  end * 86400
                )
              )
            )
        ),
        ultimo_consumo_em =
          i.ultimo_consumo_em +
          (
            floor(
              extract(epoch from (now() - i.ultimo_consumo_em)) /
              (
                case
                  when i.frequencia_uso = 'Semanal' then 7
                  when i.frequencia_uso = 'Mensal' then 30
                  else 1
                end * 86400
              )
            ) *
            case
              when i.frequencia_uso = 'Semanal' then 7
              when i.frequencia_uso = 'Mensal' then 30
              else 1
            end
          ) * interval '1 day'
      where i.consumo_medio_diario is not null
        and i.consumo_medio_diario > 0
        and i.frequencia_uso is not null
        and now() - i.ultimo_consumo_em >=
          (
            case
              when i.frequencia_uso = 'Semanal' then 7
              when i.frequencia_uso = 'Mensal' then 30
              else 1
            end
          ) * interval '1 day'
        ${idosoClause}
    `,
    params,
  );
}
