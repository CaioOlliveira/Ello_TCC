import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  deleteRow,
  getRowById,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarTemperaturaInput,
  CriarTemperaturaInput,
} from "./temperatura.schemas.js";

const table = "registros_temperatura";
const notFound = [
  "TEMPERATURA_NAO_ENCONTRADA",
  "Registro de temperatura nao encontrado.",
] as const;

const faixaPadrao = {
  minimo: 36.1,
  maximo: 37.2,
  febreLeveMaximo: 38.0,
};

const fields = {
  idosoId: "idoso_id",
  temperatura: "temperatura_celsius",
  medidoEm: "medido_em",
  observacoes: "observacoes",
  registradoPorId: "registrado_por_id",
} as const;

type TemperaturaRow = {
  id: string;
  idosoId: string;
  temperatura: number | string;
  medidoEm: Date | string;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type RegistroTemperatura = {
  id: string;
  idosoId: string;
  temperatura: number;
  medidoEm: string;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type PeriodoTemperatura = "dia" | "semanal" | "mes";

type HistoricoTemperaturaEntrada = {
  id: string;
  usuarioNome: string;
  acao: "criar" | "atualizar" | "remover";
  descricao: string;
  temperatura: number | null;
  dataHora: string;
  badge: { texto: string; cor: "normal" | "alerta" | "atualizado" | "neutro" };
};

const temperaturasMemoria: RegistroTemperatura[] = [];
let schemaReady = false;

const toIsoString = (value: Date | string) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const mapearTemperatura = (row: TemperaturaRow): RegistroTemperatura => ({
  id: row.id,
  idosoId: row.idosoId,
  temperatura: Number(row.temperatura),
  medidoEm: toIsoString(row.medidoEm),
  observacoes: row.observacoes,
  registradoPorId: row.registradoPorId,
});

const round1 = (value: number) => Math.round(value * 10) / 10;

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
  return round1(values.reduce((sum, value) => sum + value, 0) / values.length);
};

const classificarTemperatura = (temperatura?: number | null) => {
  if (temperatura == null) {
    return {
      status: "sem_registro",
      titulo: "Sem medicao registrada",
      mensagem: "Registre a primeira temperatura para gerar alertas.",
      cor: "neutro",
    };
  }

  if (temperatura < faixaPadrao.minimo) {
    return {
      status: "baixa",
      titulo: "Temperatura abaixo da faixa",
      mensagem:
        "Valor abaixo do esperado. Acompanhe a evolucao e registre sintomas.",
      cor: "atencao",
    };
  }

  if (temperatura <= faixaPadrao.maximo) {
    return {
      status: "dentro",
      titulo: "Dentro da faixa configurada",
      mensagem: "Dentro da faixa configurada pelo profissional de saude.",
      cor: "ok",
    };
  }

  if (temperatura <= faixaPadrao.febreLeveMaximo) {
    return {
      status: "febril_leve",
      titulo: "Febre baixa (estado febril)",
      mensagem:
        "Valores acima da faixa ideal. Caso ocorram sintomas, acompanhe a evolucao.",
      cor: "atencao",
    };
  }

  return {
    status: "febre",
    titulo: "Febre",
    mensagem:
      "Valores indicam febre. Considere buscar orientacao profissional.",
    cor: "critico",
  };
};

const criarSerieDiaria = (
  registros: RegistroTemperatura[],
  dataReferencia: Date,
) => {
  const inicio = startOfDay(dataReferencia);
  inicio.setDate(inicio.getDate() - 6);

  return Array.from({ length: 7 }, (_, index) => {
    const dia = new Date(inicio);
    dia.setDate(inicio.getDate() + index);
    const valores = registros
      .filter((registro) => sameDay(new Date(registro.medidoEm), dia))
      .map((registro) => registro.temperatura);

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
  registros: RegistroTemperatura[],
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
      .map((registro) => registro.temperatura);

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
  registros: RegistroTemperatura[],
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
      .map((registro) => registro.temperatura);

    return {
      data: mesInicio.toISOString().substring(0, 10),
      rotulo: mesInicio.toLocaleDateString("pt-BR", { month: "short" }),
      valor: average(valores),
    };
  });
};

const criarSerie = (
  registros: RegistroTemperatura[],
  dataReferencia: Date,
  periodo: PeriodoTemperatura,
) => {
  if (periodo === "semanal") return criarSerieSemanal(registros, dataReferencia);
  if (periodo === "mes") return criarSerieMensal(registros, dataReferencia);
  return criarSerieDiaria(registros, dataReferencia);
};

const montarAnalise = (registros: RegistroTemperatura[]) => {
  const agora = new Date();
  const limite = new Date(agora);
  limite.setDate(limite.getDate() - 7);

  const ultimos7Dias = registros.filter(
    (registro) => new Date(registro.medidoEm) >= limite,
  );
  const mediaTemperatura = average(
    ultimos7Dias.map((registro) => registro.temperatura),
  );
  const foraDaFaixa = ultimos7Dias.filter(
    (registro) =>
      registro.temperatura < faixaPadrao.minimo ||
      registro.temperatura > faixaPadrao.maximo,
  ).length;

  if (ultimos7Dias.length === 0 || mediaTemperatura == null) {
    return {
      mediaUltimos7Dias: null,
      totalMedicoes: 0,
      totalForaDaFaixa: 0,
      texto:
        "Ainda nao ha medicoes suficientes para gerar uma analise da temperatura.",
    };
  }

  const textoBase = `A media de ${mediaTemperatura}°C nos ultimos 7 dias`;
  const textoFaixa =
    foraDaFaixa === 0
      ? "permanece dentro da faixa esperada. Continue assim!"
      : `teve ${foraDaFaixa} medicao(oes) fora da faixa. Caso ocorram febre persistente ou outros sintomas, registre as novas medicoes e acompanhe a evolucao.`;

  return {
    mediaUltimos7Dias: mediaTemperatura,
    totalMedicoes: ultimos7Dias.length,
    totalForaDaFaixa: foraDaFaixa,
    texto: `${textoBase} ${textoFaixa}`,
  };
};

const montarResumo = (
  registros: RegistroTemperatura[],
  dataReferencia = new Date(),
  periodo: PeriodoTemperatura = "dia",
) => {
  const ordenados = [...registros].sort(
    (a, b) => new Date(b.medidoEm).getTime() - new Date(a.medidoEm).getTime(),
  );

  const ultima = ordenados[0] ?? null;
  const registrosDoDia = ordenados.filter((registro) =>
    sameDay(new Date(registro.medidoEm), dataReferencia),
  );
  const mediaTemperaturaDia = average(
    registrosDoDia.map((registro) => registro.temperatura),
  );
  const proximaMedicao = ultima
    ? new Date(
        new Date(ultima.medidoEm).getTime() + 8 * 60 * 60 * 1000,
      ).toISOString()
    : null;

  return {
    ultima,
    totalRegistros: registrosDoDia.length,
    totalRegistrosGeral: ordenados.length,
    mediaTemperaturaDia,
    proximaMedicao,
    faixa: faixaPadrao,
    alerta: classificarTemperatura(ultima?.temperatura),
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
      temperatura_celsius numeric not null check (temperatura_celsius >= 25 and temperatura_celsius <= 45),
      medido_em timestamptz not null default now(),
      observacoes text,
      registrado_por_id uuid references usuarios(id),
      criado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    create index if not exists idx_registros_temperatura_idoso_medido
      on ${table} (idoso_id, medido_em desc)
  `);

  schemaReady = true;
};

const buscarTemperaturas = async (
  idosoId: string,
): Promise<RegistroTemperatura[]> => {
  if (!isDatabaseEnabled) {
    return temperaturasMemoria.filter(
      (registro) => registro.idosoId === idosoId,
    );
  }

  await ensureSchema();

  const result = await getPool().query<TemperaturaRow>(
    `
      select
        id,
        idoso_id as "idosoId",
        temperatura_celsius as temperatura,
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

  return result.rows.map(mapearTemperatura);
};

const dadosDoRegistro = (dados: Record<string, unknown> | null | undefined) => {
  if (!dados) return { temperatura: null };
  const temperatura = dados.temperatura ?? dados.temperatura_celsius;
  return {
    temperatura:
      typeof temperatura === "number" ? temperatura : Number(temperatura) || null,
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
}): HistoricoTemperaturaEntrada => {
  const novos = dadosDoRegistro(row.dadosNovos);
  const anteriores = dadosDoRegistro(row.dadosAnteriores);

  if (row.acao === "criar") {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "criar",
      descricao: "registrou temperatura",
      temperatura: novos.temperatura,
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
      temperatura: anteriores.temperatura,
      dataHora: dataHoraDoRegistro(row.dadosAnteriores, row.criadoEm),
      badge: { texto: "Removido", cor: "alerta" },
    };
  }

  const valorMudou =
    novos.temperatura != null && novos.temperatura !== anteriores.temperatura;
  const observacoesMudaram =
    observacoesDoRegistro(row.dadosNovos) !==
    observacoesDoRegistro(row.dadosAnteriores);

  if (valorMudou) {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "atualizar",
      descricao: "atualizou valor",
      temperatura: novos.temperatura ?? anteriores.temperatura,
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
      temperatura: novos.temperatura ?? anteriores.temperatura,
      dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
      badge: { texto: "Alerta", cor: "alerta" },
    };
  }

  return {
    id: row.id,
    usuarioNome: row.usuarioNome,
    acao: "atualizar",
    descricao: "atualizou registro",
    temperatura: novos.temperatura ?? anteriores.temperatura,
    dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
    badge: { texto: "Atualizado", cor: "atualizado" },
  };
};

const inicioDoPeriodoHistorico = (
  referencia: Date,
  periodo: PeriodoTemperatura,
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

export const temperaturaService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    if (!isDatabaseEnabled) {
      const registros = idosoId
        ? temperaturasMemoria.filter((registro) => registro.idosoId === idosoId)
        : temperaturasMemoria;

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
    const result = await getPool().query<TemperaturaRow>(
      `
        select
          id,
          idoso_id as "idosoId",
          temperatura_celsius as temperatura,
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
      dados: result.rows.map(mapearTemperatura),
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
    periodo: PeriodoTemperatura = "dia",
  ) {
    const referencia = dataReferencia
      ? new Date(`${dataReferencia}T12:00:00`)
      : new Date();
    const registros = await buscarTemperaturas(idosoId);

    return montarResumo(registros, referencia, periodo);
  },

  async historico(
    idosoId: string,
    dataReferencia?: string,
    periodo: PeriodoTemperatura = "dia",
  ): Promise<HistoricoTemperaturaEntrada[]> {
    const referencia = dataReferencia
      ? new Date(`${dataReferencia}T12:00:00`)
      : new Date();
    const inicio = inicioDoPeriodoHistorico(referencia, periodo);

    if (!isDatabaseEnabled) {
      return temperaturasMemoria
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

  async criar(input: CriarTemperaturaInput) {
    if (isDatabaseEnabled) {
      await ensureSchema();
      const registradoPorId = await resolverUsuarioRegistroId(
        input.registradoPorId,
      );

      const result = await getPool().query<TemperaturaRow>(
        `
          insert into ${table} (
            idoso_id,
            temperatura_celsius,
            medido_em,
            observacoes,
            registrado_por_id
          )
          values ($1, $2, $3, $4, $5)
          returning
            id,
            idoso_id as "idosoId",
            temperatura_celsius as temperatura,
            medido_em as "medidoEm",
            observacoes,
            registrado_por_id as "registradoPorId"
        `,
        [
          input.idosoId,
          input.temperatura,
          input.medidoEm,
          input.observacoes ?? null,
          registradoPorId,
        ],
      );

      const temperatura = mapearTemperatura(result.rows[0]);
      await registrarHistorico({
        usuarioId: registradoPorId,
        idosoId: input.idosoId,
        acao: "criar",
        tipoEntidade: table,
        entidadeId: String(temperatura.id),
        dadosNovos: temperatura,
      });

      return temperatura;
    }

    const temperatura: RegistroTemperatura = {
      id: `temperatura-${Date.now()}`,
      idosoId: input.idosoId,
      temperatura: input.temperatura,
      medidoEm: input.medidoEm,
      observacoes: input.observacoes,
      registradoPorId: input.registradoPorId,
    };
    temperaturasMemoria.unshift(temperatura);

    return temperatura;
  },

  async atualizar(id: string, input: AtualizarTemperaturaInput) {
    await ensureSchema();
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarTemperaturaInput,
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
