import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  deleteRow,
  getRowById,
  updateRow,
} from "../../database/simple-crud.js";
import {
  formatLocalDate,
  parseLocalDate,
  periodRange,
  sameLocalDay,
  startOfLocalDay,
} from "../../common/utils/date-utils.js";
import type {
  AtualizarOxigenacaoInput,
  CriarOxigenacaoInput,
} from "./oxigenacao.schemas.js";

const table = "registros_oxigenacao";
const notFound = [
  "OXIGENACAO_NAO_ENCONTRADA",
  "Registro de oxigenacao nao encontrado.",
] as const;

const faixaPadrao = {
  saturacaoMinimo: 95,
  saturacaoMaximo: 100,
};

// A tabela registros_oxigenacao ja existia no banco (provisionada fora
// deste modulo) com as colunas fisicas spo2 / frequencia_cardiaca /
// registrado_em. Mantemos os nomes saturacao / pulso / medidoEm apenas
// no contrato da API (schemas, mobile), mapeando para as colunas reais aqui.
const fields = {
  idosoId: "idoso_id",
  saturacao: "spo2",
  pulso: "frequencia_cardiaca",
  medidoEm: "registrado_em",
  observacoes: "observacoes",
  registradoPorId: "registrado_por_id",
} as const;

type OxigenacaoRow = {
  id: string;
  idosoId: string;
  saturacao: number | string;
  pulso: number | string | null;
  medidoEm: Date | string;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type RegistroOxigenacao = {
  id: string;
  idosoId: string;
  saturacao: number;
  pulso: number | null;
  medidoEm: string;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type PeriodoOxigenacao = "dia" | "semanal" | "mes";

type HistoricoOxigenacaoEntrada = {
  id: string;
  usuarioNome: string;
  acao: "criar" | "atualizar" | "remover";
  descricao: string;
  saturacao: number | null;
  pulso: number | null;
  dataHora: string;
  badge: { texto: string; cor: "normal" | "alerta" | "atualizado" | "neutro" };
};

const oxigenacoesMemoria: RegistroOxigenacao[] = [];
let schemaReady = false;

const toIsoString = (value: Date | string) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const mapearOxigenacao = (row: OxigenacaoRow): RegistroOxigenacao => ({
  id: row.id,
  idosoId: row.idosoId,
  saturacao: Number(row.saturacao),
  pulso: row.pulso == null ? null : Number(row.pulso),
  medidoEm: toIsoString(row.medidoEm),
  observacoes: row.observacoes,
  registradoPorId: row.registradoPorId,
});

const round = (value: number) => Math.round(value);

const startOfWeek = (date: Date) => {
  const copy = startOfLocalDay(date);
  const day = copy.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  copy.setDate(copy.getDate() + diff);
  return copy;
};

const average = (values: number[]) => {
  if (values.length === 0) return null;
  return round(values.reduce((sum, value) => sum + value, 0) / values.length);
};

const classificarOxigenacao = (saturacao?: number | null) => {
  if (saturacao == null) {
    return {
      status: "sem_registro",
      titulo: "Sem medicao registrada",
      mensagem: "Registre a primeira oxigenacao para gerar alertas.",
      cor: "neutro",
    };
  }

  if (saturacao >= faixaPadrao.saturacaoMinimo) {
    return {
      status: "dentro",
      titulo: "Dentro da faixa configurada",
      mensagem: "Dentro da faixa configurada pelo profissional de saude.",
      cor: "ok",
    };
  }

  if (saturacao >= 91) {
    return {
      status: "leve",
      titulo: "Saturacao levemente baixa",
      mensagem:
        "Valor abaixo de 95%. Acompanhe a evolucao e registre sintomas.",
      cor: "atencao",
    };
  }

  return {
    status: "baixa",
    titulo: "Saturacao baixa",
    mensagem:
      "Valor igual ou abaixo de 90%. Considere buscar orientacao profissional.",
    cor: "critico",
  };
};

const criarSerieDiaria = (
  registros: RegistroOxigenacao[],
  dataReferencia: Date,
) => {
  const inicio = startOfLocalDay(dataReferencia);
  inicio.setDate(inicio.getDate() - 6);

  return Array.from({ length: 7 }, (_, index) => {
    const dia = new Date(inicio);
    dia.setDate(inicio.getDate() + index);
    const valores = registros
      .filter((registro) => sameLocalDay(new Date(registro.medidoEm), dia))
      .map((registro) => registro.saturacao);

    return {
      data: formatLocalDate(dia),
      rotulo: dia.toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "2-digit",
      }),
      valor: average(valores),
    };
  });
};

const criarSerieSemanal = (
  registros: RegistroOxigenacao[],
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
      .map((registro) => registro.saturacao);

    return {
      data: formatLocalDate(semanaInicio),
      rotulo: semanaInicio.toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "2-digit",
      }),
      valor: average(valores),
    };
  });
};

const criarSerieMensal = (
  registros: RegistroOxigenacao[],
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
      .map((registro) => registro.saturacao);

    return {
      data: formatLocalDate(mesInicio),
      rotulo: mesInicio.toLocaleDateString("pt-BR", { month: "short" }),
      valor: average(valores),
    };
  });
};

const criarSerie = (
  registros: RegistroOxigenacao[],
  dataReferencia: Date,
  periodo: PeriodoOxigenacao,
) => {
  if (periodo === "semanal")
    return criarSerieSemanal(registros, dataReferencia);
  if (periodo === "mes") return criarSerieMensal(registros, dataReferencia);
  return criarSerieDiaria(registros, dataReferencia);
};

const montarAnalise = (registros: RegistroOxigenacao[]) => {
  const agora = new Date();
  const limite = new Date(agora);
  limite.setDate(limite.getDate() - 7);

  const ultimos7Dias = registros.filter(
    (registro) => new Date(registro.medidoEm) >= limite,
  );
  const mediaSaturacao = average(
    ultimos7Dias.map((registro) => registro.saturacao),
  );
  const pulsosValidos = ultimos7Dias
    .map((registro) => registro.pulso)
    .filter((valor): valor is number => valor != null);
  const mediaPulso = average(pulsosValidos);
  const foraDaFaixa = ultimos7Dias.filter(
    (registro) => registro.saturacao < faixaPadrao.saturacaoMinimo,
  ).length;

  if (ultimos7Dias.length === 0 || mediaSaturacao == null) {
    return {
      mediaUltimos7Dias: null,
      mediaPulsoUltimos7Dias: null,
      totalMedicoes: 0,
      totalForaDaFaixa: 0,
      texto:
        "Ainda nao ha medicoes suficientes para gerar uma analise da oxigenacao.",
    };
  }

  const textoBase = `A media de ${mediaSaturacao}% de saturacao nos ultimos 7 dias`;
  const textoFaixa =
    foraDaFaixa === 0
      ? "permanece dentro da faixa ideal e bastante estavel. Continue assim!"
      : `teve ${foraDaFaixa} medicao(oes) fora da faixa.`;

  return {
    mediaUltimos7Dias: mediaSaturacao,
    mediaPulsoUltimos7Dias: mediaPulso,
    totalMedicoes: ultimos7Dias.length,
    totalForaDaFaixa: foraDaFaixa,
    texto: `${textoBase} ${textoFaixa}`,
  };
};

const montarResumo = (
  registros: RegistroOxigenacao[],
  dataReferencia = new Date(),
  periodo: PeriodoOxigenacao = "dia",
) => {
  const ordenados = [...registros].sort(
    (a, b) => new Date(b.medidoEm).getTime() - new Date(a.medidoEm).getTime(),
  );

  const registrosDoDia = ordenados.filter((registro) =>
    sameLocalDay(new Date(registro.medidoEm), dataReferencia),
  );
  const ultima = registrosDoDia[0] ?? null;
  const mediaSaturacaoDia = average(
    registrosDoDia.map((registro) => registro.saturacao),
  );
  const pulsosDoDia = registrosDoDia
    .map((registro) => registro.pulso)
    .filter((valor): valor is number => valor != null);
  const mediaPulsoDia = average(pulsosDoDia);
  const proximaMedicao = ultima
    ? new Date(
        new Date(ultima.medidoEm).getTime() + 8 * 60 * 60 * 1000,
      ).toISOString()
    : null;

  return {
    ultima,
    totalRegistros: registrosDoDia.length,
    totalRegistrosGeral: ordenados.length,
    mediaSaturacaoDia,
    mediaPulsoDia,
    proximaMedicao,
    faixa: faixaPadrao,
    alerta: classificarOxigenacao(ultima?.saturacao),
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
      spo2 numeric not null check (spo2 >= 0 and spo2 <= 100),
      frequencia_cardiaca integer check (frequencia_cardiaca is null or (frequencia_cardiaca >= 20 and frequencia_cardiaca <= 250)),
      registrado_em timestamptz not null default now(),
      observacoes text,
      registrado_por_id uuid not null references usuarios(id)
    )
  `);

  await getPool().query(`
    create index if not exists idx_registros_oxigenacao_idoso_registrado
      on ${table} (idoso_id, registrado_em desc)
  `);

  schemaReady = true;
};

const buscarOxigenacoes = async (
  idosoId: string,
): Promise<RegistroOxigenacao[]> => {
  if (!isDatabaseEnabled) {
    return oxigenacoesMemoria.filter(
      (registro) => registro.idosoId === idosoId,
    );
  }

  await ensureSchema();

  const result = await getPool().query<OxigenacaoRow>(
    `
      select
        id,
        idoso_id as "idosoId",
        spo2 as saturacao,
        frequencia_cardiaca as pulso,
        registrado_em as "medidoEm",
        observacoes,
        registrado_por_id as "registradoPorId"
      from ${table}
      where idoso_id = $1
      order by registrado_em desc
      limit 120
    `,
    [idosoId],
  );

  return result.rows.map(mapearOxigenacao);
};

const dadosDoRegistro = (dados: Record<string, unknown> | null | undefined) => {
  if (!dados) return { saturacao: null, pulso: null };
  const saturacao = dados.saturacao ?? dados.spo2;
  const pulso = dados.pulso ?? dados.frequencia_cardiaca;
  return {
    saturacao:
      typeof saturacao === "number" ? saturacao : Number(saturacao) || null,
    pulso:
      pulso == null
        ? null
        : typeof pulso === "number"
          ? pulso
          : Number(pulso) || null,
  };
};

const observacoesDoRegistro = (
  dados: Record<string, unknown> | null | undefined,
) => (dados?.observacoes == null ? null : String(dados.observacoes));

const dataHoraDoRegistro = (
  dados: Record<string, unknown> | null | undefined,
  fallback: Date | string,
) => {
  const medidoEm = dados?.medidoEm ?? dados?.registrado_em;
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
}): HistoricoOxigenacaoEntrada => {
  const novos = dadosDoRegistro(row.dadosNovos);
  const anteriores = dadosDoRegistro(row.dadosAnteriores);

  if (row.acao === "criar") {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "criar",
      descricao: "registrou oxigenação",
      saturacao: novos.saturacao,
      pulso: novos.pulso,
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
      saturacao: anteriores.saturacao,
      pulso: anteriores.pulso,
      dataHora: dataHoraDoRegistro(row.dadosAnteriores, row.criadoEm),
      badge: { texto: "Removido", cor: "alerta" },
    };
  }

  const valorMudou =
    (novos.saturacao != null && novos.saturacao !== anteriores.saturacao) ||
    (novos.pulso != null && novos.pulso !== anteriores.pulso);
  const observacoesMudaram =
    observacoesDoRegistro(row.dadosNovos) !==
    observacoesDoRegistro(row.dadosAnteriores);

  if (valorMudou) {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "atualizar",
      descricao: "atualizou valor",
      saturacao: novos.saturacao ?? anteriores.saturacao,
      pulso: novos.pulso ?? anteriores.pulso,
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
      saturacao: novos.saturacao ?? anteriores.saturacao,
      pulso: novos.pulso ?? anteriores.pulso,
      dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
      badge: { texto: "Alerta", cor: "alerta" },
    };
  }

  return {
    id: row.id,
    usuarioNome: row.usuarioNome,
    acao: "atualizar",
    descricao: "atualizou registro",
    saturacao: novos.saturacao ?? anteriores.saturacao,
    pulso: novos.pulso ?? anteriores.pulso,
    dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
    badge: { texto: "Atualizado", cor: "atualizado" },
  };
};

export const oxigenacaoService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    if (!isDatabaseEnabled) {
      const registros = idosoId
        ? oxigenacoesMemoria.filter((registro) => registro.idosoId === idosoId)
        : oxigenacoesMemoria;

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
    const result = await getPool().query<OxigenacaoRow>(
      `
        select
          id,
          idoso_id as "idosoId",
          spo2 as saturacao,
          frequencia_cardiaca as pulso,
          registrado_em as "medidoEm",
          observacoes,
          registrado_por_id as "registradoPorId"
        from ${table}
        ${where}
        order by registrado_em desc
        limit ${limitParam}
        offset ${offsetParam}
      `,
      params,
    );

    return {
      dados: result.rows.map(mapearOxigenacao),
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
    periodo: PeriodoOxigenacao = "dia",
  ) {
    const referencia = parseLocalDate(dataReferencia);
    const registros = await buscarOxigenacoes(idosoId);

    return montarResumo(registros, referencia, periodo);
  },

  async historico(
    idosoId: string,
    dataReferencia?: string,
    periodo: PeriodoOxigenacao = "dia",
  ): Promise<HistoricoOxigenacaoEntrada[]> {
    const referencia = parseLocalDate(dataReferencia);
    const { start: inicio, endExclusive: fim } = periodRange(
      referencia,
      periodo,
    );

    if (!isDatabaseEnabled) {
      return oxigenacoesMemoria
        .filter(
          (registro) =>
            registro.idosoId === idosoId &&
            new Date(registro.medidoEm) >= inicio &&
            new Date(registro.medidoEm) < fim,
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
          and h.criado_em < $4
        order by h.criado_em desc
        limit 100
      `,
      [idosoId, table, inicio.toISOString(), fim.toISOString()],
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

  async criar(input: CriarOxigenacaoInput) {
    if (isDatabaseEnabled) {
      await ensureSchema();
      const registradoPorId = await resolverUsuarioRegistroId(
        input.registradoPorId,
      );

      const result = await getPool().query<OxigenacaoRow>(
        `
          insert into ${table} (
            idoso_id,
            spo2,
            frequencia_cardiaca,
            registrado_em,
            observacoes,
            registrado_por_id
          )
          values ($1, $2, $3, $4, $5, $6)
          returning
            id,
            idoso_id as "idosoId",
            spo2 as saturacao,
            frequencia_cardiaca as pulso,
            registrado_em as "medidoEm",
            observacoes,
            registrado_por_id as "registradoPorId"
        `,
        [
          input.idosoId,
          input.saturacao,
          input.pulso ?? null,
          input.medidoEm,
          input.observacoes ?? null,
          registradoPorId,
        ],
      );

      const oxigenacao = mapearOxigenacao(result.rows[0]);
      await registrarHistorico({
        usuarioId: registradoPorId,
        idosoId: input.idosoId,
        acao: "criar",
        tipoEntidade: table,
        entidadeId: String(oxigenacao.id),
        dadosNovos: oxigenacao,
      });

      return oxigenacao;
    }

    const oxigenacao: RegistroOxigenacao = {
      id: `oxigenacao-${Date.now()}`,
      idosoId: input.idosoId,
      saturacao: input.saturacao,
      pulso: input.pulso ?? null,
      medidoEm: input.medidoEm,
      observacoes: input.observacoes,
      registradoPorId: input.registradoPorId,
    };
    oxigenacoesMemoria.unshift(oxigenacao);

    return oxigenacao;
  },

  async atualizar(id: string, input: AtualizarOxigenacaoInput) {
    await ensureSchema();
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarOxigenacaoInput,
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
