import { getPool } from "../../database/pool.js";

export const dashboardService = {
  async obterResumo(idosoId: string) {
    const pool = getPool();

    const [
      idoso,
      ultimaGlicemia,
      alimentacaoHoje,
      proximosEventos,
      insumosAcabando,
      equipamentosManutencao,
      medicamentosAtivos,
    ] = await Promise.all([
      pool.query(
        "select * from fichas_idosos where id = $1 and ativo = true limit 1",
        [idosoId],
      ),
      pool.query(
        "select * from registros_glicemia where idoso_id = $1 order by medido_em desc limit 1",
        [idosoId],
      ),
      pool.query(
        `
          select count(*)::int as total
          from registros_alimentacao
          where idoso_id = $1
            and alimentou_em::date = current_date
        `,
        [idosoId],
      ),
      pool.query(
        `
          select *
          from eventos_calendario
          where idoso_id = $1
            and inicio_em >= now()
          order by inicio_em asc
          limit 5
        `,
        [idosoId],
      ),
      pool.query(
        `
          select *
          from insumos
          where idoso_id = $1
            and alerta_minimo_unidades is not null
            and quantidade_unidades <= alerta_minimo_unidades
          order by quantidade_unidades asc
          limit 5
        `,
        [idosoId],
      ),
      pool.query(
        `
          select *
          from equipamentos
          where idoso_id = $1
            and proxima_manutencao_em is not null
            and proxima_manutencao_em <= current_date + interval '15 days'
          order by proxima_manutencao_em asc
          limit 5
        `,
        [idosoId],
      ),
      pool.query(
        `
          select count(*)::int as total
          from medicamentos
          where idoso_id = $1 and ativo = true
        `,
        [idosoId],
      ),
    ]);

    return {
      idoso: idoso.rows[0] ?? null,
      ultimaGlicemia: ultimaGlicemia.rows[0] ?? null,
      alimentacaoHoje: {
        refeicoesRegistradas: alimentacaoHoje.rows[0]?.total ?? 0,
      },
      proximosEventos: proximosEventos.rows,
      insumosAcabando: insumosAcabando.rows,
      equipamentosManutencao: equipamentosManutencao.rows,
      medicamentos: {
        ativos: medicamentosAtivos.rows[0]?.total ?? 0,
      },
      dicaInformativa:
        "Acompanhe os registros e procure um profissional de saúde em caso de dúvidas ou alterações importantes.",
    };
  },
};
