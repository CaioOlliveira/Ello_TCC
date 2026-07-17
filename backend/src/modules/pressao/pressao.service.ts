import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  deleteRow,
  getRowById,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarPressaoInput,
  CriarPressaoInput,
} from "./pressao.schemas.js";

const table = "registros_pressao";
const notFound = [
  "PRESSAO_NAO_ENCONTRADA",
  "Registro de pressao nao encontrado.",
] as const;

const faixaPadrao = {
  sistolicaMinimo: 90,
  sistolicaMaximo: 130,
  diastolicaMinimo: 60,
  diastolicaMaximo: 85,
};

const fields = {
  idosoId: "idoso_id",
  sistolica: "sistolica",
  diastolica: "diastolica",
  batimentos: "batimentos",
  medidoEm: "medido_em",
  observacoes: "observacoes",
  registradoPorId: "registrado_por_id",
} as const;

type PressaoRow = {
  id: string;
  idosoId: string;
  sistolica: number | string;
  diastolica: number | string;
  batimentos: number | string | null;
  medidoEm: Date | string;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type RegistroPressao = {
  id: string;
  idosoId: string;
  sistolica: number;
  diastolica: number;
  batimentos: number | null;
  medidoEm: string;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type PeriodoPressao = "dia" | "semanal" | "mes";

type HistoricoPressaoEntrada = {
  id: string;
  usuarioNome: string;
  acao: "criar" | "atualizar" | "remover";
  descricao: string;
  sistolica: number | null;
  diastolica: number | null;
  dataHora: string;
  badge: { texto: string; cor: "normal" | "alerta" | "atualizado" | "neutro" };
};

const pressoesMemoria: RegistroPressao[] = [];
let schemaReady = false;

const toIsoString = (value: Date | string) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const mapearPressao = (row: PressaoRow): RegistroPressao => ({
  id: row.id,
  idosoId: row.idosoId,
  sistolica: Number(row.sistolica),
  diastolica: Number(row.diastolica),
  batimentos: row.batimentos == null ? null : Number(row.batimentos),
  medidoEm: toIsoString(row.medidoEm),
  observacoes: row.observacoes,
  registradoPorId: row.registradoPorId,
});

const round = (value: number) => Math.round(value);

const startOfDay = (date: Date) => {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
};

const sameDay = (value: Date, reference: Date) =>
  value.getFullYear() === reference.getFullYear() &&
  value.getMonth() === reference.getMonth() &&
  value.getDate() === reference.getDate();

const startOfWeek = (date: Date) => {
  const copy = startOfDay(date);
  const day = copy.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  copy.setDate(copy.getDate() + diff);
  return copy;
};

const average = (values: number[]) => {
  if (values.length === 0) return null;
  return round(values.reduce((sum, value) => sum + value, 0) / values.length);
};

const classificarPressao = (
  sistolica?: number | null,
  diastolica?: number | null,
) => {
  if (sistolica == null || diastolica == null) {
    return {
      status: "sem_registro",
      titulo: "Sem medicao registrada",
      mensagem: "Registre a primeira pressao para gerar alertas.",
      cor: "neutro",
    };
  }

  if (
    sistolica < faixaPadrao.sistolicaMinimo ||
    diastolica < faixaPadrao.diastolicaMinimo
  ) {
    return {
      status: "baixa",
      titulo: "Pressao abaixo da faixa",
      mensagem:
        "Valores abaixo do esperado. Observe sintomas e siga a orientacao profissional.",
      cor: "alerta",
    };
  }

  if (
    sistolica <= faixaPadrao.sistolicaMaximo &&
    diastolica <= faixaPadrao.diastolicaMaximo
  ) {
    return {
      status: "dentro",
      titulo: "Dentro da faixa configurada",
      mensagem: "Dentro da faixa configurada pelo profissional de saude.",
      cor: "ok",
    };
  }

  if (sistolica <= 139 && diastolica <= 89) {
    return {
      status: "elevada",
      titulo: "Pressao levemente elevada",
      mensagem:
        "Valores acima da faixa ideal. Acompanhe a evolucao e registre sintomas.",
      cor: "atencao",
    };
  }

  return {
    status: "alta",
    titulo: "Pressao alta",
    mensagem:
      "Valores indicam pressao alta. Considere buscar orientacao profissional.",
    cor: "critico",
  };
};

const criarSerieDiaria = (
  registros: RegistroPressao[],
  dataReferencia: Date,
) => {
  const inicio = startOfDay(dataReferencia);
  inicio.setDate(inicio.getDate() - 6);

  return Array.from({ length: 7 }, (_, index) => {
    const dia = new Date(inicio);
    dia.setDate(inicio.getDate() + index);
    const valores = registros
      .filter((registro) => sameDay(new Date(registro.medidoEm), dia))
      .map((registro) => registro.sistolica);

    return {
      data: dia.toISOString().substring(0, 10),
      rotulo: dia.toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "2-digit",
      }),
      valor: average(valores),
    };
  });
};

const criarSerieSemanal = (
  registros: RegistroPressao[],
  dataReferencia: Date,
) => {
  const inicio = startOfWeek(dataReferencia);
  inicio.setDate(inicio.getDate() - 6 * 7);

  return Array.from({ length: 7 }, (_, index) => {
    const semanaInicio = new Date(inicio);
    semanaInicio.setDate(inicio.getDate() + index * 7);
    const semanaFim = new Date(semanaInicio);
    semanaFim.setDate(semanaInicio.getDate() + 7);
    const valores = registros
      .filter((registro) => {
        const data = new Date(registro.medidoEm);
        return data >= semanaInicio && data < semanaFim;
      })
      .map((registro) => registro.sistolica);

    return {
      data: semanaInicio.toISOString().substring(0, 10),
      rotulo: semanaInicio.toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "2-digit",
      }),
      valor: average(valores),
    };
  });
};

const criarSerieMensal = (
  registros: RegistroPressao[],
  dataReferencia: Date,
) => {
  const inicio = new Date(
    dataReferencia.getFullYear(),
    dataReferencia.getMonth() - 6,
    1,
  );

  return Array.from({ length: 7 }, (_, index) => {
    const mesInicio = new Date(
      inicio.getFullYear(),
      inicio.getMonth() + index,
      1,
    );
    const mesFim = new Date(
      mesInicio.getFullYear(),
      mesInicio.getMonth() + 1,
      1,
    );
    const valores = registros
      .filter((registro) => {
        const data = new Date(registro.medidoEm);
        return data >= mesInicio && data < mesFim;
      })
      .map((registro) => registro.sistolica);

    return {
      data: mesInicio.toISOString().substring(0, 10),
      rotulo: mesInicio.toLocaleDateString("pt-BR", { month: "short" }),
      valor: average(valores),
    };
  });
};

const criarSerie = (
  registros: RegistroPressao[],
  dataReferencia: Date,
  periodo: PeriodoPressao,
) => {
  if (periodo === "semanal") return criarSerieSemanal(registros, dataReferencia);
  if (periodo === "mes") return criarSerieMensal(registros, dataReferencia);
  return criarSerieDiaria(registros, dataReferencia);
};

const montarAnalise = (registros: RegistroPressao[]) => {
  const agora = new Date();
  const limite = new Date(agora);
  limite.setDate(limite.getDate() - 7);

  const ultimos7Dias = registros.filter(
    (registro) => new Date(registro.medidoEm) >= limite,
  );
  const mediaSistolica = average(
    ultimos7Dias.map((registro) => registro.sistolica),
  );
  const mediaDiastolica = average(
    ultimos7Dias.map((registro) => registro.diastolica),
  );
  const foraDaFaixa = ultimos7Dias.filter(
    (registro) =>
      registro.sistolica < faixaPadrao.sistolicaMinimo ||
      registro.sistolica > faixaPadrao.sistolicaMaximo ||
      registro.diastolica < faixaPadrao.diastolicaMinimo ||
      registro.diastolica > faixaPadrao.diastolicaMaximo,
  ).length;

  if (ultimos7Dias.length === 0 || mediaSistolica == null || mediaDiastolica == null) {
    return {
      mediaUltimos7Dias: null,
      totalMedicoes: 0,
      totalForaDaFaixa: 0,
      texto:
        "Ainda nao ha medicoes suficientes para gerar uma analise da pressao.",
    };
  }

  const textoBase = `A media de ${mediaSistolica}/${mediaDiastolica} mmHg nos ultimos 7 dias`;
  const textoFaixa =
    foraDaFaixa === 0
      ? "permanece dentro da faixa ideal e bastante estavel. Continue assim!"
      : `teve ${foraDaFaixa} medicao(oes) fora da faixa.`;

  return {
    mediaUltimos7Dias: mediaSistolica,
    mediaDiastolicaUltimos7Dias: mediaDiastolica,
    totalMedicoes: ultimos7Dias.length,
    totalForaDaFaixa: foraDaFaixa,
    texto: `${textoBase} ${textoFaixa}`,
  };
};

const montarResumo = (
  registros: RegistroPressao[],
  dataReferencia = new Date(),
  periodo: PeriodoPressao = "dia",
) => {
  const ordenados = [...registros].sort(
    (a, b) => new Date(b.medidoEm).getTime() - new Date(a.medidoEm).getTime(),
  );

  const ultima = ordenados[0] ?? null;
  const registrosDoDia = ordenados.filter((registro) =>
    sameDay(new Date(registro.medidoEm), dataReferencia),
  );
  const mediaSistolicaDia = average(
    registrosDoDia.map((registro) => registro.sistolica),
  );
  const mediaDiastolicaDia = average(
    registrosDoDia.map((registro) => registro.diastolica),
  );
  const proximaMedicao = ultima
    ? new Date(
        new Date(ultima.medidoEm).getTime() + 8 * 60 * 60 * 1000,
      ).toISOString()
    : null;

  return {
    ultima,
    totalRegistros: ordenados.length,
    mediaSistolicaDia,
    mediaDiastolicaDia,
    proximaMedicao,
    faixa: faixaPadrao,
    alerta: classificarPressao(ultima?.sistolica, ultima?.diastolica),
    analise: montarAnalise(ordenados),
    serie: criarSerie(ordenados, dataReferencia, periodo),
  };
};

const ensureSchema = async () => {
  if (!isDatabaseEnabled || schemaReady) return;

  await getPool().query(`
    create table if not exists ${table} (
      id uuid primary key default gen_random_uuid(),
      idoso_id uuid not null references fichas_idosos(id) on delete cascade,
      sistolica integer not null check (sistolica >= 40 and sistolica <= 300),
      diastolica integer not null check (diastolica >= 20 and diastolica <= 200),
      batimentos integer check (batimentos is null or (batimentos >= 20 and batimentos <= 250)),
      medido_em timestamptz not null,
      observacoes text,
      registrado_por_id uuid references usuarios(id),
      criado_em timestamptz not null default now(),
      atualizado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    create index if not exists idx_registros_pressao_idoso_medido
      on ${table} (idoso_id, medido_em desc)
  `);

  schemaReady = true;
};

const buscarPressoes = async (idosoId: string): Promise<RegistroPressao[]> => {
  if (!isDatabaseEnabled) {
    return pressoesMemoria.filter((registro) => registro.idosoId === idosoId);
  }

  await ensureSchema();

  const result = await getPool().query<PressaoRow>(
    `
      select
        id,
        idoso_id as "idosoId",
        sistolica,
        diastolica,
        batimentos,
        medido_em as "medidoEm",
        observacoes,
        registrado_por_id as "registradoPorId"
      from ${table}
      where idoso_id = $1
      order by medido_em desc
      limit 120
    `,
    [idosoId],
  );

  return result.rows.map(mapearPressao);
};

const dadosDoRegistro = (dados: Record<string, unknown> | null | undefined) => {
  if (!dados) return { sistolica: null, diastolica: null };
  const sistolica = dados.sistolica;
  const diastolica = dados.diastolica;
  return {
    sistolica: typeof sistolica === "number" ? sistolica : Number(sistolica) || null,
    diastolica:
      typeof diastolica === "number" ? diastolica : Number(diastolica) || null,
  };
};

const observacoesDoRegistro = (
  dados: Record<string, unknown> | null | undefined,
) => (dados?.observacoes == null ? null : String(dados.observacoes));

const dataHoraDoRegistro = (
  dados: Record<string, unknown> | null | undefined,
  fallback: Date | string,
) => {
  const medidoEm = dados?.medidoEm ?? dados?.medido_em;
  if (medidoEm) {
    const parsed = toIsoString(medidoEm as Date | string);
    if (!Number.isNaN(new Date(parsed).getTime())) return parsed;
  }
  return toIsoString(fallback);
};

const montarEntradaHistorico = (row: {
  id: string;
  acao: string;
  dadosAnteriores: Record<string, unknown> | null;
  dadosNovos: Record<string, unknown> | null;
  criadoEm: Date | string;
  usuarioNome: string;
}): HistoricoPressaoEntrada => {
  const novos = dadosDoRegistro(row.dadosNovos);
  const anteriores = dadosDoRegistro(row.dadosAnteriores);

  if (row.acao === "criar") {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "criar",
      descricao: "registrou pressão",
      sistolica: novos.sistolica,
      diastolica: novos.diastolica,
      dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
      badge: { texto: "Normal", cor: "normal" },
    };
  }

  if (row.acao === "remover") {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "remover",
      descricao: "removeu registro",
      sistolica: anteriores.sistolica,
      diastolica: anteriores.diastolica,
      dataHora: dataHoraDoRegistro(row.dadosAnteriores, row.criadoEm),
      badge: { texto: "Removido", cor: "alerta" },
    };
  }

  const valorMudou =
    (novos.sistolica != null && novos.sistolica !== anteriores.sistolica) ||
    (novos.diastolica != null && novos.diastolica !== anteriores.diastolica);
  const observacoesMudaram =
    observacoesDoRegistro(row.dadosNovos) !==
    observacoesDoRegistro(row.dadosAnteriores);

  if (valorMudou) {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "atualizar",
      descricao: "atualizou valor",
      sistolica: novos.sistolica ?? anteriores.sistolica,
      diastolica: novos.diastolica ?? anteriores.diastolica,
      dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
      badge: { texto: "Atualizado", cor: "atualizado" },
    };
  }

  if (observacoesMudaram) {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "atualizar",
      descricao: "editou observação",
      sistolica: novos.sistolica ?? anteriores.sistolica,
      diastolica: novos.diastolica ?? anteriores.diastolica,
      dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
      badge: { texto: "Alerta", cor: "alerta" },
    };
  }

  return {
    id: row.id,
    usuarioNome: row.usuarioNome,
    acao: "atualizar",
    descricao: "atualizou registro",
    sistolica: novos.sistolica ?? anteriores.sistolica,
    diastolica: novos.diastolica ?? anteriores.diastolica,
    dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
    badge: { texto: "Atualizado", cor: "atualizado" },
  };
};

const inicioDoPeriodoHistorico = (
  referencia: Date,
  periodo: PeriodoPressao,
) => {
  if (periodo === "semanal") {
    const inicio = startOfDay(referencia);
    inicio.setDate(inicio.getDate() - 6);
    return inicio;
  }

  if (periodo === "mes") {
    const inicio = startOfDay(referencia);
    inicio.setDate(inicio.getDate() - 29);
    return inicio;
  }

  return startOfDay(referencia);
};

export const pressaoService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    if (!isDatabaseEnabled) {
      const registros = idosoId
        ? pressoesMemoria.filter((registro) => registro.idosoId === idosoId)
        : pressoesMemoria;

      return {
        dados: registros.slice(offset, offset + limit),
        total: registros.length,
      };
    }

    await ensureSchema();

    const params = idosoId ? [idosoId, limit, offset] : [limit, offset];
    const where = idosoId ? "where idoso_id = $1" : "";
    const limitParam = idosoId ? "$2" : "$1";
    const offsetParam = idosoId ? "$3" : "$2";

    const countResult = await getPool().query<{ total: string }>(
      `select count(*) as total from ${table} ${where}`,
      idosoId ? [idosoId] : [],
    );
    const result = await getPool().query<PressaoRow>(
      `
        select
          id,
          idoso_id as "idosoId",
          sistolica,
          diastolica,
          batimentos,
          medido_em as "medidoEm",
          observacoes,
          registrado_por_id as "registradoPorId"
        from ${table}
        ${where}
        order by medido_em desc
        limit ${limitParam}
        offset ${offsetParam}
      `,
      params,
    );

    return {
      dados: result.rows.map(mapearPressao),
      total: Number(countResult.rows[0]?.total ?? 0),
    };
  },

  async buscarPorId(id: string) {
    await ensureSchema();
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async resumo(
    idosoId: string,
    dataReferencia?: string,
    periodo: PeriodoPressao = "dia",
  ) {
    const referencia = dataReferencia
      ? new Date(`${dataReferencia}T12:00:00`)
      : new Date();
    const registros = await buscarPressoes(idosoId);

    return montarResumo(registros, referencia, periodo);
  },

  async historico(
    idosoId: string,
    dataReferencia?: string,
    periodo: PeriodoPressao = "dia",
  ): Promise<HistoricoPressaoEntrada[]> {
    const referencia = dataReferencia
      ? new Date(`${dataReferencia}T12:00:00`)
      : new Date();
    const inicio = inicioDoPeriodoHistorico(referencia, periodo);

    if (!isDatabaseEnabled) {
      return pressoesMemoria
        .filter(
          (registro) =>
            registro.idosoId === idosoId &&
            new Date(registro.medidoEm) >= inicio,
        )
        .map((registro) =>
          montarEntradaHistorico({
            id: registro.id,
            acao: "criar",
            dadosAnteriores: null,
            dadosNovos: registro as unknown as Record<string, unknown>,
            criadoEm: registro.medidoEm,
            usuarioNome: "Cuidador",
          }),
        );
    }

    await ensureSchema();

    const result = await getPool().query<{
      id: string;
      acao: string;
      dadosAnteriores: Record<string, unknown> | null;
      dadosNovos: Record<string, unknown> | null;
      criadoEm: Date;
      usuarioNome: string | null;
    }>(
      `
        select
          h.id,
          h.acao,
          h.dados_anteriores as "dadosAnteriores",
          h.dados_novos as "dadosNovos",
          h.criado_em as "criadoEm",
          coalesce(u.nome, 'Cuidador') as "usuarioNome"
        from historico_alteracoes h
        left join usuarios u on u.id = h.usuario_id
        where h.idoso_id = $1
          and h.tipo_entidade = $2
          and h.criado_em >= $3
        order by h.criado_em desc
        limit 100
      `,
      [idosoId, table, inicio.toISOString()],
    );

    return result.rows.map((row) =>
      montarEntradaHistorico({
        id: row.id,
        acao: row.acao,
        dadosAnteriores: row.dadosAnteriores,
        dadosNovos: row.dadosNovos,
        criadoEm: row.criadoEm,
        usuarioNome: row.usuarioNome ?? "Cuidador",
      }),
    );
  },

  async criar(input: CriarPressaoInput) {
    if (isDatabaseEnabled) {
      await ensureSchema();
      const registradoPorId = await resolverUsuarioRegistroId(
        input.registradoPorId,
      );

      const result = await getPool().query<PressaoRow>(
        `
          insert into ${table} (
            idoso_id,
            sistolica,
            diastolica,
            batimentos,
            medido_em,
            observacoes,
            registrado_por_id
          )
          values ($1, $2, $3, $4, $5, $6, $7)
          returning
            id,
            idoso_id as "idosoId",
            sistolica,
            diastolica,
            batimentos,
            medido_em as "medidoEm",
            observacoes,
            registrado_por_id as "registradoPorId"
        `,
        [
          input.idosoId,
          input.sistolica,
          input.diastolica,
          input.batimentos ?? null,
          input.medidoEm,
          input.observacoes ?? null,
          registradoPorId,
        ],
      );

      const pressao = mapearPressao(result.rows[0]);
      await registrarHistorico({
        usuarioId: registradoPorId,
        idosoId: input.idosoId,
        acao: "criar",
        tipoEntidade: table,
        entidadeId: String(pressao.id),
        dadosNovos: pressao,
      });

      return pressao;
    }

    const pressao: RegistroPressao = {
      id: `pressao-${Date.now()}`,
      idosoId: input.idosoId,
      sistolica: input.sistolica,
      diastolica: input.diastolica,
      batimentos: input.batimentos ?? null,
      medidoEm: input.medidoEm,
      observacoes: input.observacoes,
      registradoPorId: input.registradoPorId,
    };
    pressoesMemoria.unshift(pressao);

    return pressao;
  },

  async atualizar(id: string, input: AtualizarPressaoInput) {
    await ensureSchema();
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarPressaoInput,
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
    await ensureSchema();
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
