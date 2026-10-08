import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import type { ListarHistoricoQuery } from "./historico.schemas.js";

const entidadesPorTipo = {
  insumos: ["insumos"],
  alimentacao: ["registros_alimentacao"],
  humor: ["registros_humor"],
  equipamentos: ["equipamentos", "manutencoes_equipamentos"],
  medicamentos: [
    "medicamentos",
    "administracoes_medicamentos",
    "horarios_medicamentos",
  ],
  temperatura: ["registros_temperatura"],
  agenda: ["tarefas"],
  glicemia: ["registros_glicemia", "registros_insulina"],
  pressao: ["registros_pressao", "registros_pressao_arterial"],
  oxigenacao: ["registros_oxigenacao"],
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

const dataConsumoAlimentacaoSql = `
  coalesce(
    h.dados_novos ->> 'dataConsumo',
    h.dados_anteriores ->> 'dataConsumo',
    h.dados_novos ->> 'data_consumo',
    h.dados_anteriores ->> 'data_consumo'
  )
`;

const dataEventoHistoricoSql = `
  case
    when h.tipo_entidade = 'registros_alimentacao'
      and left(coalesce(${dataConsumoAlimentacaoSql}, ''), 10)
        ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    then left(${dataConsumoAlimentacaoSql}, 10)::date
    else (h.criado_em at time zone 'America/Sao_Paulo')::date
  end
`;

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
            when h.tipo_entidade in ('equipamentos', 'manutencoes_equipamentos') then
              coalesce(
                e.nome,
                h.dados_novos ->> 'nome',
                h.dados_anteriores ->> 'nome',
                'Equipamento'
              )
            when h.tipo_entidade in (
              'medicamentos',
              'administracoes_medicamentos',
              'horarios_medicamentos'
            ) then
              coalesce(
                m.nome,
                h.dados_novos ->> 'nome',
                h.dados_anteriores ->> 'nome',
                h.dados_novos ->> 'medicamentoNome',
                h.dados_anteriores ->> 'medicamentoNome',
                h.dados_novos ->> 'medicamento_nome',
                h.dados_anteriores ->> 'medicamento_nome',
                'Medicamento'
              )
            when h.tipo_entidade = 'tarefas' then
              coalesce(
                h.dados_novos ->> 'titulo',
                h.dados_anteriores ->> 'titulo',
                'Compromisso'
              )
            when h.tipo_entidade = 'registros_insulina' then
              coalesce(
                h.dados_novos ->> 'nomeInsulina',
                h.dados_anteriores ->> 'nomeInsulina',
                h.dados_novos ->> 'nome_insulina',
                h.dados_anteriores ->> 'nome_insulina',
                'Insulina'
              )
            when h.tipo_entidade = 'registros_glicemia' then 'Glicemia'
            when h.tipo_entidade in (
              'registros_pressao',
              'registros_pressao_arterial'
            ) then 'Pressao arterial'
            when h.tipo_entidade = 'registros_oxigenacao' then 'Oxigenacao'
            when h.tipo_entidade = 'registros_temperatura' then 'Temperatura'
            else 'Registro'
          end as item_nome,
          h.dados_anteriores,
          h.dados_novos
        from historico_alteracoes h
        left join usuarios u on u.id::text = h.usuario_id::text
        left join insumos i
          on i.id::text = h.entidade_id::text
         and h.tipo_entidade = 'insumos'
        left join equipamentos e
          on e.id::text = case
            when h.tipo_entidade = 'equipamentos' then h.entidade_id::text
            when h.tipo_entidade = 'manutencoes_equipamentos' then coalesce(
              h.dados_novos ->> 'equipamento_id',
              h.dados_anteriores ->> 'equipamento_id',
              h.dados_novos ->> 'equipamentoId',
              h.dados_anteriores ->> 'equipamentoId'
            )
          end
        left join medicamentos m
          on m.id::text = case
            when h.tipo_entidade = 'medicamentos' then h.entidade_id::text
            when h.tipo_entidade = 'horarios_medicamentos' then coalesce(
              h.dados_novos ->> 'medicamentoId',
              h.dados_anteriores ->> 'medicamentoId',
              h.entidade_id::text
            )
            when h.tipo_entidade = 'administracoes_medicamentos' then coalesce(
              h.dados_novos ->> 'medicamento_id',
              h.dados_anteriores ->> 'medicamento_id',
              h.dados_novos ->> 'medicamentoId',
              h.dados_anteriores ->> 'medicamentoId'
            )
          end
        where h.idoso_id::text = $1
          and h.tipo_entidade = any($2::text[])
          and (${dataEventoHistoricoSql}) >= $3::date
          and (${dataEventoHistoricoSql}) <= $4::date
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
