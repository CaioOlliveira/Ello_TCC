import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import type { ListarHistoricoQuery } from "./historico.schemas.js";

const entidadesPorTipo = {
  insumos: ["insumos"],
  alimentacao: ["registros_alimentacao"],
  humor: ["registros_humor"],
} satisfies Record<ListarHistoricoQuery["tipo"], string[]>;

type HistoricoRow = {
  id: string;
  acao: string;
  tipo_entidade: string;
  entidade_id: string;
  usuario_id: string | null;
  usuario_nome: string | null;
  criado_em: string;
  item_nome: string | null;
  dados_anteriores: unknown;
  dados_novos: unknown;
};

export const historicoService = {
  async listar({ idosoId, tipo, inicio, fim, limite }: ListarHistoricoQuery) {
    if (!isDatabaseEnabled) return [];

    const entidades = entidadesPorTipo[tipo];
    const result = await getPool().query<HistoricoRow>(
      `
        select
          h.id,
          h.acao,
          h.tipo_entidade,
          h.entidade_id,
          h.usuario_id,
          coalesce(u.nome, 'Usuario') as usuario_nome,
          h.criado_em,
          case
            when h.tipo_entidade = 'insumos' then
              coalesce(
                i.nome,
                h.dados_novos ->> 'nome',
                h.dados_anteriores ->> 'nome',
                'Insumo'
              )
            when h.tipo_entidade = 'registros_alimentacao' then
              coalesce(
                h.dados_novos ->> 'tipoRefeicao',
                h.dados_anteriores ->> 'tipoRefeicao',
                h.dados_novos ->> 'tipo_refeicao',
                h.dados_anteriores ->> 'tipo_refeicao',
                'Refeicao'
              )
            when h.tipo_entidade = 'registros_humor' then
              coalesce(
                h.dados_novos ->> 'humor',
                h.dados_anteriores ->> 'humor',
                'Humor'
              )
            else 'Registro'
          end as item_nome,
          h.dados_anteriores,
          h.dados_novos
        from historico_alteracoes h
        left join usuarios u on u.id = h.usuario_id
        left join insumos i
          on i.id = h.entidade_id
         and h.tipo_entidade = 'insumos'
        where h.idoso_id = $1
          and h.tipo_entidade = any($2::text[])
          and h.criado_em >= $3::date
          and h.criado_em < ($4::date + interval '1 day')
        order by h.criado_em desc
        limit $5
      `,
      [idosoId, entidades, inicio, fim, limite],
    );

    return result.rows.map((row) => ({
      id: row.id,
      acao: row.acao,
      tipoEntidade: row.tipo_entidade,
      entidadeId: row.entidade_id,
      usuarioId: row.usuario_id,
      usuarioNome: row.usuario_nome ?? "Usuario",
      criadoEm: row.criado_em,
      itemNome: row.item_nome ?? "Registro",
      dadosAnteriores: row.dados_anteriores,
      dadosNovos: row.dados_novos,
    }));
  },
};
