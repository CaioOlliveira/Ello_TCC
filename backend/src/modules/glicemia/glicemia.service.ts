import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  deleteRow,
  getRowById,
  updateRow,
} from "../../database/simple-crud.js";
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
  tipoInsulina: string;
  doseUnidades: number | string;
  aplicadoEm: Date | string;
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
  tipoInsulina: string;
  doseUnidades: number;
  aplicadoEm: string;
  observacoes?: string | null;
  registradoPorId?: string | null;
};

type PeriodoGlicemia = "dia" | "semanal" | "mes";

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
  tipoInsulina: row.tipoInsulina,
  doseUnidades: Number(row.doseUnidades),
  aplicadoEm: toIsoString(row.aplicadoEm),
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
  const inicio = startOfDay(dataReferencia);
  inicio.setDate(inicio.getDate() - 6);

  return Array.from({ length: 7 }, (_, index) => {
    const dia = new Date(inicio);
    dia.setDate(inicio.getDate() + index);
    const valores = registros
      .filter((registro) => sameDay(new Date(registro.medidoEm), dia))
      .map((registro) => registro.valor);

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
      data: mesInicio.toISOString().substring(0, 10),
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
  if (periodo === "semanal") return criarSerieSemanal(registros, dataReferencia);
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
      registro.valor < faixaPadrao.minimo || registro.valor > faixaPadrao.maximo,
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
    (a, b) =>
      new Date(b.medidoEm).getTime() - new Date(a.medidoEm).getTime(),
  );
  const insulinasOrdenadas = [...insulinas].sort(
    (a, b) =>
      new Date(b.aplicadoEm).getTime() - new Date(a.aplicadoEm).getTime(),
  );

  const ultima = ordenados[0] ?? null;
  const valoresDoDia = ordenados
    .filter((registro) => sameDay(new Date(registro.medidoEm), dataReferencia))
    .map((registro) => registro.valor);
  const mediaDia = average(valoresDoDia);
  const proximaMedicao = ultima
    ? new Date(new Date(ultima.medidoEm).getTime() + 3 * 60 * 60 * 1000)
        .toISOString()
    : null;

  return {
    ultima,
    totalRegistros: ordenados.length,
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
      tipo_insulina text not null,
      dose_unidades numeric(6, 2) not null check (dose_unidades > 0 and dose_unidades <= 200),
      aplicado_em timestamptz not null,
      observacoes text,
      registrado_por_id uuid references usuarios(id),
      criado_em timestamptz not null default now(),
      atualizado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    create index if not exists idx_registros_insulina_idoso_aplicado
      on ${insulinaTable} (idoso_id, aplicado_em desc)
  `);

  insulinaSchemaReady = true;
};

const buscarGlicemias = async (idosoId: string): Promise<RegistroGlicemia[]> => {
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

const buscarInsulinas = async (idosoId: string): Promise<RegistroInsulina[]> => {
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
        tipo_insulina as "tipoInsulina",
        dose_unidades as "doseUnidades",
        aplicado_em as "aplicadoEm",
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
    const referencia = dataReferencia
      ? new Date(`${dataReferencia}T12:00:00`)
      : new Date();
    const [registros, insulinas] = await Promise.all([
      buscarGlicemias(idosoId),
      buscarInsulinas(idosoId),
    ]);

    return montarResumo(registros, insulinas, referencia, periodo);
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
            tipo_insulina,
            dose_unidades,
            aplicado_em,
            observacoes,
            registrado_por_id
          )
          values ($1, $2, $3, $4, $5, $6, $7)
          returning
            id,
            idoso_id as "idosoId",
            glicemia_id as "glicemiaId",
            tipo_insulina as "tipoInsulina",
            dose_unidades as "doseUnidades",
            aplicado_em as "aplicadoEm",
            observacoes,
            registrado_por_id as "registradoPorId"
        `,
        [
          input.idosoId,
          input.glicemiaId ?? null,
          input.tipoInsulina,
          input.doseUnidades,
          input.aplicadoEm,
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
      tipoInsulina: input.tipoInsulina,
      doseUnidades: input.doseUnidades,
      aplicadoEm: input.aplicadoEm,
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
