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
  AtualizarGlicemiaInput,
  CriarGlicemiaInput,
  CriarInsulinaInput,
} from "./glicemia.schemas.js";

const table = "registros_glicemia";
const insulinaTable = "registros_insulina";
const notFound = [
  "GLICEMIA_NAO_ENCONTRADA",
  "Registro de glicemia nao encontrado.",
] as const;

const faixaPadrao = {
  minimo: 70,
  maximo: 180,
};

const fields = {
  idosoId: "idoso_id",
  valor: "valor_mg_dl",
  contexto: "contexto_medicao",
  medidoEm: "medido_em",
  observacoes: "observacoes",
  sintomas: "sintomas",
  registradoPorId: "registrado_por_id",
} as const;

type GlicemiaRow = {
  id: string;
  idosoId: string;
  valor: number | string;
  contexto: string;
  medidoEm: Date | string;
  observacoes?: string | null;
  sintomas?: string | null;
  registradoPorId?: string | null;
};

type InsulinaRow = {
  id: string;
  idosoId: string;
  glicemiaId?: string | null;
  nomeInsulina?: string | null;
  tipoInsulina: string;
  doseUnidades: number | string;
  aplicadoEm: Date | string;
  localAplicacao?: string | null;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type RegistroGlicemia = {
  id: string;
  idosoId: string;
  valor: number;
  contexto: string;
  medidoEm: string;
  observacoes?: string | null;
  sintomas?: string | null;
  registradoPorId?: string | null;
};

type RegistroInsulina = {
  id: string;
  idosoId: string;
  glicemiaId?: string | null;
  nomeInsulina?: string | null;
  tipoInsulina: string;
  doseUnidades: number;
  aplicadoEm: string;
  localAplicacao?: string | null;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type PeriodoGlicemia = "dia" | "semanal" | "mes";

type HistoricoGlicemiaEntrada = {
  id: string;
  usuarioNome: string;
  acao: "criar" | "atualizar" | "remover";
  descricao: string;
  valor: number | null;
  dataHora: string;
  badge: { texto: string; cor: "normal" | "alerta" | "atualizado" | "neutro" };
};

const glicemiasMemoria: RegistroGlicemia[] = [];
const insulinasMemoria: RegistroInsulina[] = [];
let insulinaSchemaReady = false;

const toIsoString = (value: Date | string) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const mapearGlicemia = (row: GlicemiaRow): RegistroGlicemia => ({
  id: row.id,
  idosoId: row.idosoId,
  valor: Number(row.valor),
  contexto: row.contexto,
  medidoEm: toIsoString(row.medidoEm),
  observacoes: row.observacoes,
  sintomas: row.sintomas,
  registradoPorId: row.registradoPorId,
});

const mapearInsulina = (row: InsulinaRow): RegistroInsulina => ({
  id: row.id,
  idosoId: row.idosoId,
  glicemiaId: row.glicemiaId,
  nomeInsulina: row.nomeInsulina,
  tipoInsulina: row.tipoInsulina,
  doseUnidades: Number(row.doseUnidades),
  aplicadoEm: toIsoString(row.aplicadoEm),
  localAplicacao: row.localAplicacao,
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

const classificarGlicemia = (valor?: number | null) => {
  if (valor == null) {
    return {
      status: "sem_registro",
      titulo: "Sem medicao registrada",
      mensagem: "Registre a primeira glicemia para gerar alertas.",
      cor: "neutro",
    };
  }

  if (valor < faixaPadrao.minimo) {
    return {
      status: "baixa",
      titulo: "Glicemia abaixo da faixa",
      mensagem:
        "Valor abaixo de 70 mg/dL. Observe sintomas e siga a orientacao profissional.",
      cor: "alerta",
    };
  }

  if (valor <= faixaPadrao.maximo) {
    return {
      status: "dentro",
      titulo: "Dentro da faixa configurada",
      mensagem: "Dentro da faixa configurada pelo profissional de saude.",
      cor: "ok",
    };
  }

  if (valor <= 250) {
    return {
      status: "alta",
      titulo: "Glicemia acima da faixa",
      mensagem:
        "Valor acima de 180 mg/dL. Acompanhe a evolucao e registre sintomas.",
      cor: "atencao",
    };
  }

  return {
    status: "muito_alta",
    titulo: "Glicemia muito alta",
    mensagem:
      "Valor acima de 250 mg/dL. Considere buscar orientacao profissional.",
    cor: "critico",
  };
};

const criarSerieDiaria = (
  registros: RegistroGlicemia[],
  dataReferencia: Date,
) => {
  const inicio = startOfLocalDay(dataReferencia);
  inicio.setDate(inicio.getDate() - 6);

  return Array.from({ length: 7 }, (_, index) => {
    const dia = new Date(inicio);
    dia.setDate(inicio.getDate() + index);
    const valores = registros
      .filter((registro) => sameLocalDay(new Date(registro.medidoEm), dia))
      .map((registro) => registro.valor);

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
  registros: RegistroGlicemia[],
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
      .map((registro) => registro.valor);

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
  registros: RegistroGlicemia[],
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
      .map((registro) => registro.valor);

    return {
      data: formatLocalDate(mesInicio),
      rotulo: mesInicio.toLocaleDateString("pt-BR", { month: "short" }),
      valor: average(valores),
    };
  });
};

const criarSerie = (
  registros: RegistroGlicemia[],
  dataReferencia: Date,
  periodo: PeriodoGlicemia,
) => {
  if (periodo === "semanal")
    return criarSerieSemanal(registros, dataReferencia);
  if (periodo === "mes") return criarSerieMensal(registros, dataReferencia);
  return criarSerieDiaria(registros, dataReferencia);
};

const montarAnalise = (registros: RegistroGlicemia[]) => {
  const agora = new Date();
  const limite = new Date(agora);
  limite.setDate(limite.getDate() - 7);

  const ultimos7Dias = registros.filter(
    (registro) => new Date(registro.medidoEm) >= limite,
  );
  const mediaUltimos7Dias = average(
    ultimos7Dias.map((registro) => registro.valor),
  );
  const foraDaFaixa = ultimos7Dias.filter(
    (registro) =>
      registro.valor < faixaPadrao.minimo ||
      registro.valor > faixaPadrao.maximo,
  ).length;

  if (ultimos7Dias.length === 0 || mediaUltimos7Dias == null) {
    return {
      mediaUltimos7Dias: null,
      totalMedicoes: 0,
      totalForaDaFaixa: 0,
      texto:
        "Ainda nao ha medicoes suficientes para gerar uma analise da glicemia.",
    };
  }

  const textoBase = `A media de ${mediaUltimos7Dias} mg/dL nos ultimos 7 dias`;
  const textoFaixa =
    foraDaFaixa === 0
      ? "permanece dentro da faixa configurada."
      : `teve ${foraDaFaixa} medicao(oes) fora da faixa.`;

  return {
    mediaUltimos7Dias,
    totalMedicoes: ultimos7Dias.length,
    totalForaDaFaixa: foraDaFaixa,
    texto: `${textoBase} ${textoFaixa}`,
  };
};

const montarResumo = (
  registros: RegistroGlicemia[],
  insulinas: RegistroInsulina[],
  dataReferencia = new Date(),
  periodo: PeriodoGlicemia = "dia",
) => {
  const ordenados = [...registros].sort(
    (a, b) => new Date(b.medidoEm).getTime() - new Date(a.medidoEm).getTime(),
  );
  const insulinasOrdenadas = [...insulinas].sort(
    (a, b) =>
      new Date(b.aplicadoEm).getTime() - new Date(a.aplicadoEm).getTime(),
  );

  const registrosDoDia = ordenados.filter((registro) =>
    sameLocalDay(new Date(registro.medidoEm), dataReferencia),
  );
  const ultima = registrosDoDia[0] ?? null;
  const valoresDoDia = registrosDoDia.map((registro) => registro.valor);
  const mediaDia = average(valoresDoDia);
  const proximaMedicao = ultima
    ? new Date(
        new Date(ultima.medidoEm).getTime() + 3 * 60 * 60 * 1000,
      ).toISOString()
    : null;

  return {
    ultima,
    totalRegistros: registrosDoDia.length,
    mediaDia,
    proximaMedicao,
    faixa: faixaPadrao,
    alerta: classificarGlicemia(ultima?.valor),
    analise: montarAnalise(ordenados),
    serie: criarSerie(ordenados, dataReferencia, periodo),
    insulinaRecente: insulinasOrdenadas[0] ?? null,
    totalInsulinas: insulinasOrdenadas.length,
  };
};

const ensureInsulinaSchema = async () => {
  if (!isDatabaseEnabled || insulinaSchemaReady) return;

  await getPool().query(`
    create table if not exists ${insulinaTable} (
      id uuid primary key default gen_random_uuid(),
      idoso_id uuid not null references fichas_idosos(id) on delete cascade,
      glicemia_id uuid references registros_glicemia(id) on delete set null,
      nome_insulina text,
      tipo_insulina text not null,
      dose_unidades numeric(6, 2) not null check (dose_unidades > 0 and dose_unidades <= 200),
      aplicado_em timestamptz not null,
      local_aplicacao text,
      observacoes text,
      registrado_por_id uuid references usuarios(id),
      criado_em timestamptz not null default now(),
      atualizado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    alter table ${insulinaTable}
      add column if not exists nome_insulina text,
      add column if not exists local_aplicacao text
  `);

  await getPool().query(`
    create index if not exists idx_registros_insulina_idoso_aplicado
      on ${insulinaTable} (idoso_id, aplicado_em desc)
  `);

  insulinaSchemaReady = true;
};

const buscarGlicemias = async (
  idosoId: string,
): Promise<RegistroGlicemia[]> => {
  if (!isDatabaseEnabled) {
    return glicemiasMemoria.filter((registro) => registro.idosoId === idosoId);
  }

  const result = await getPool().query<GlicemiaRow>(
    `
      select
        id,
        idoso_id as "idosoId",
        valor_mg_dl as valor,
        contexto_medicao as contexto,
        medido_em as "medidoEm",
        observacoes,
        sintomas,
        registrado_por_id as "registradoPorId"
      from ${table}
      where idoso_id = $1
      order by medido_em desc
      limit 120
    `,
    [idosoId],
  );

  return result.rows.map(mapearGlicemia);
};

const buscarInsulinas = async (
  idosoId: string,
): Promise<RegistroInsulina[]> => {
  if (!isDatabaseEnabled) {
    return insulinasMemoria.filter((registro) => registro.idosoId === idosoId);
  }

  await ensureInsulinaSchema();

  const result = await getPool().query<InsulinaRow>(
    `
      select
        id,
        idoso_id as "idosoId",
        glicemia_id as "glicemiaId",
        nome_insulina as "nomeInsulina",
        tipo_insulina as "tipoInsulina",
        dose_unidades as "doseUnidades",
        aplicado_em as "aplicadoEm",
        local_aplicacao as "localAplicacao",
        observacoes,
        registrado_por_id as "registradoPorId"
      from ${insulinaTable}
      where idoso_id = $1
      order by aplicado_em desc
      limit 60
    `,
    [idosoId],
  );

  return result.rows.map(mapearInsulina);
};

const valorDoRegistro = (dados: Record<string, unknown> | null | undefined) => {
  if (!dados) return null;
  const valor = dados.valor ?? dados.valor_mg_dl;
  return typeof valor === "number" ? valor : Number(valor) || null;
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
}): HistoricoGlicemiaEntrada => {
  const valorNovo = valorDoRegistro(row.dadosNovos);
  const valorAnterior = valorDoRegistro(row.dadosAnteriores);

  if (row.acao === "criar") {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "criar",
      descricao: "registrou medição",
      valor: valorNovo,
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
      valor: valorAnterior,
      dataHora: dataHoraDoRegistro(row.dadosAnteriores, row.criadoEm),
      badge: { texto: "Removido", cor: "alerta" },
    };
  }

  const valorMudou = valorNovo != null && valorNovo !== valorAnterior;
  const observacoesMudaram =
    observacoesDoRegistro(row.dadosNovos) !==
    observacoesDoRegistro(row.dadosAnteriores);

  if (valorMudou) {
    return {
      id: row.id,
      usuarioNome: row.usuarioNome,
      acao: "atualizar",
      descricao: "atualizou valor",
      valor: valorNovo,
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
      valor: valorNovo ?? valorAnterior,
      dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
      badge: { texto: "Alerta", cor: "alerta" },
    };
  }

  return {
    id: row.id,
    usuarioNome: row.usuarioNome,
    acao: "atualizar",
    descricao: "atualizou registro",
    valor: valorNovo ?? valorAnterior,
    dataHora: dataHoraDoRegistro(row.dadosNovos, row.criadoEm),
    badge: { texto: "Atualizado", cor: "atualizado" },
  };
};

export const glicemiaService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    if (!isDatabaseEnabled) {
      const registros = idosoId
        ? glicemiasMemoria.filter((registro) => registro.idosoId === idosoId)
        : glicemiasMemoria;

      return {
        dados: registros.slice(offset, offset + limit),
        total: registros.length,
      };
    }

    const params = idosoId ? [idosoId, limit, offset] : [limit, offset];
    const where = idosoId ? "where idoso_id = $1" : "";
    const limitParam = idosoId ? "$2" : "$1";
    const offsetParam = idosoId ? "$3" : "$2";

    const countResult = await getPool().query<{ total: string }>(
      `select count(*) as total from ${table} ${where}`,
      idosoId ? [idosoId] : [],
    );
    const result = await getPool().query<GlicemiaRow>(
      `
        select
          id,
          idoso_id as "idosoId",
          valor_mg_dl as valor,
          contexto_medicao as contexto,
          medido_em as "medidoEm",
          observacoes,
          sintomas,
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
      dados: result.rows.map(mapearGlicemia),
      total: Number(countResult.rows[0]?.total ?? 0),
    };
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async resumo(
    idosoId: string,
    dataReferencia?: string,
    periodo: PeriodoGlicemia = "dia",
  ) {
    const referencia = parseLocalDate(dataReferencia);
    const [registros, insulinas] = await Promise.all([
      buscarGlicemias(idosoId),
      buscarInsulinas(idosoId),
    ]);

    return montarResumo(registros, insulinas, referencia, periodo);
  },

  async historico(
    idosoId: string,
    dataReferencia?: string,
    periodo: PeriodoGlicemia = "dia",
  ): Promise<HistoricoGlicemiaEntrada[]> {
    const referencia = parseLocalDate(dataReferencia);
    const { start: inicio, endExclusive: fim } = periodRange(
      referencia,
      periodo,
    );

    if (!isDatabaseEnabled) {
      return glicemiasMemoria
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

  async criar(input: CriarGlicemiaInput) {
    if (isDatabaseEnabled) {
      const registradoPorId = await resolverUsuarioRegistroId(
        input.registradoPorId,
      );

      const result = await getPool().query<GlicemiaRow>(
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

      const glicemia = mapearGlicemia(result.rows[0]);
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

    const glicemia: RegistroGlicemia = {
      id: `glicemia-${Date.now()}`,
      idosoId: input.idosoId,
      valor: input.valor,
      contexto: input.contexto,
      medidoEm: input.medidoEm,
      observacoes: input.observacoes,
      sintomas: input.sintomas,
      registradoPorId: input.registradoPorId,
    };
    glicemiasMemoria.unshift(glicemia);

    return glicemia;
  },

  async criarInsulina(input: CriarInsulinaInput) {
    if (isDatabaseEnabled) {
      await ensureInsulinaSchema();
      const registradoPorId = await resolverUsuarioRegistroId(
        input.registradoPorId,
      );

      const result = await getPool().query<InsulinaRow>(
        `
          insert into ${insulinaTable} (
            idoso_id,
            glicemia_id,
            nome_insulina,
            tipo_insulina,
            dose_unidades,
            aplicado_em,
            local_aplicacao,
            observacoes,
            registrado_por_id
          )
          values ($1, $2, $3, $4, $5, $6, $7, $8, $9)
          returning
            id,
            idoso_id as "idosoId",
            glicemia_id as "glicemiaId",
            nome_insulina as "nomeInsulina",
            tipo_insulina as "tipoInsulina",
            dose_unidades as "doseUnidades",
            aplicado_em as "aplicadoEm",
            local_aplicacao as "localAplicacao",
            observacoes,
            registrado_por_id as "registradoPorId"
        `,
        [
          input.idosoId,
          input.glicemiaId ?? null,
          input.nomeInsulina ?? null,
          input.tipoInsulina,
          input.doseUnidades,
          input.aplicadoEm,
          input.localAplicacao ?? null,
          input.observacoes ?? null,
          registradoPorId,
        ],
      );

      const insulina = mapearInsulina(result.rows[0]);
      await registrarHistorico({
        usuarioId: registradoPorId,
        idosoId: input.idosoId,
        acao: "criar",
        tipoEntidade: insulinaTable,
        entidadeId: String(insulina.id),
        dadosNovos: insulina,
      });

      return insulina;
    }

    const insulina: RegistroInsulina = {
      id: `insulina-${Date.now()}`,
      idosoId: input.idosoId,
      glicemiaId: input.glicemiaId,
      nomeInsulina: input.nomeInsulina,
      tipoInsulina: input.tipoInsulina,
      doseUnidades: input.doseUnidades,
      aplicadoEm: input.aplicadoEm,
      localAplicacao: input.localAplicacao,
      observacoes: input.observacoes,
      registradoPorId: input.registradoPorId,
    };
    insulinasMemoria.unshift(insulina);

    return insulina;
  },

  async listarInsulinas(limit: number, offset: number, idosoId?: string) {
    const registros = idosoId
      ? await buscarInsulinas(idosoId)
      : isDatabaseEnabled
        ? []
        : insulinasMemoria;

    return {
      dados: registros.slice(offset, offset + limit),
      total: registros.length,
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
