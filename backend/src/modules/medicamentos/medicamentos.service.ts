import { registrarHistorico } from "../../database/audit.js";
import type { PoolClient } from "pg";
import { getPool } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import { AppError } from "../../common/errors/app-error.js";
import { parseLocalDate, periodRange } from "../../common/utils/date-utils.js";
import { enviarPushMedicamento } from "../chat-familia/chat-push.service.js";
import {
  deleteRow,
  getRowById,
  insertRow,
  listRows,
  updateRow,
} from "../../database/simple-crud.js";
import type {
  AtualizarMedicamentoInput,
  CriarHorarioMedicamentoInput,
  CriarMedicamentoInput,
  RegistrarAdministracaoInput,
  SubstituirHorariosMedicamentoInput,
} from "./medicamentos.schemas.js";

type PeriodoMedicamentos = "dia" | "semanal" | "mes";

type HistoricoMedicamentoEntrada = {
  id: string;
  usuarioNome: string;
  medicamentoNome: string;
  descricao: string;
  dataHora: string;
  badge: { texto: string; cor: "normal" | "alerta" | "atualizado" | "neutro" };
};

const table = "medicamentos";
const notFound = [
  "MEDICAMENTO_NAO_ENCONTRADO",
  "Medicamento não encontrado.",
] as const;

const fields = {
  idosoId: "idoso_id",
  nome: "nome",
  dosagem: "dosagem",
  formato: "formato",
  instrucoes: "instrucoes",
  dataInicio: "data_inicio",
  dataFim: "data_fim",
  quantidadeEstoque: "quantidade_estoque",
  unidadeEstoque: "unidade_estoque",
  alertaEstoqueBaixo: "alerta_estoque_baixo",
  ativo: "ativo",
} as const;

let solicitacoesTableReady: Promise<void> | null = null;

const garantirTabelaSolicitacoesCancelamento = async () => {
  if (!solicitacoesTableReady) {
    solicitacoesTableReady = (async () => {
      await getPool().query(`
        create table if not exists solicitacoes_cancelamento_medicamento (
          id uuid primary key default gen_random_uuid(),
          idoso_id uuid not null references fichas_idosos(id) on delete cascade,
          medicamento_id uuid not null references medicamentos(id) on delete cascade,
          administracao_id uuid not null,
          solicitante_id uuid not null references usuarios(id) on delete cascade,
          responsavel_id uuid not null references usuarios(id) on delete cascade,
          status varchar(16) not null default 'pendente'
            check (status in ('pendente', 'aprovada', 'recusada')),
          respondido_por_id uuid references usuarios(id) on delete set null,
          criado_em timestamptz not null default now(),
          respondido_em timestamptz
        )
      `);
      await getPool().query(`
        create unique index if not exists solicitacao_cancelamento_dose_pendente_idx
          on solicitacoes_cancelamento_medicamento (administracao_id)
          where status = 'pendente'
      `);
      await getPool().query(`
        create index if not exists solicitacoes_cancelamento_responsavel_idx
          on solicitacoes_cancelamento_medicamento (
            responsavel_id,
            idoso_id,
            status,
            criado_em desc
          )
      `);
    })().catch((error) => {
      solicitacoesTableReady = null;
      throw error;
    });
  }
  await solicitacoesTableReady;
};

const buscarDonoFicha = async (client: PoolClient, idosoId: string) => {
  const result = await client.query<{ dono_id: string | null }>(
    `
      select coalesce(
        (
          select h.usuario_id
          from historico_alteracoes h
          where h.tipo_entidade = 'fichas_idosos'
            and h.acao = 'criar'
            and h.entidade_id::text = $1::uuid::text
            and h.usuario_id is not null
          order by h.criado_em asc
          limit 1
        ),
        f.criado_por_id
      ) as dono_id
      from fichas_idosos f
      where f.id = $1::uuid
      limit 1
    `,
    [idosoId],
  );
  const donoId = result.rows[0]?.dono_id;
  if (!donoId) {
    throw new AppError(
      "RESPONSAVEL_NAO_ENCONTRADO",
      "Responsável pela ficha não encontrado.",
      404,
    );
  }
  return donoId;
};

const podeEditarMedicacoes = async (
  client: PoolClient,
  idosoId: string,
  usuarioId: string,
) => {
  const result = await client.query<{ permitido: boolean }>(
    `
      select exists (
        select 1
        from membros_ficha mf
        where mf.idoso_id = $1
          and mf.usuario_id = $2
          and mf.status = 'ativo'
          and (
            mf.e_administrador = true
            or coalesce(mf.permissoes -> 'editar', '[]'::jsonb) ? 'Medicacoes'
          )
      ) as permitido
    `,
    [idosoId, usuarioId],
  );
  return result.rows[0]?.permitido === true;
};

const cancelarAdministracaoComCliente = async (
  client: PoolClient,
  medicamentoId: string,
  administracaoId: string,
  idosoId: string,
  usuarioId: string,
) => {
  const administracaoResult = await client.query<Record<string, unknown>>(
    `
      select am.*
      from administracoes_medicamentos am
      inner join medicamentos m on m.id = am.medicamento_id
      where am.id = $1
        and am.medicamento_id = $2
        and am.idoso_id = $3
      for update of am, m
    `,
    [administracaoId, medicamentoId, idosoId],
  );
  const administracao = administracaoResult.rows[0];

  if (!administracao) {
    throw new AppError(
      "ADMINISTRACAO_NAO_ENCONTRADA",
      "Administração não encontrada para esta ficha.",
      404,
    );
  }
  if (String(administracao.status).toLowerCase() !== "tomado") {
    throw new AppError(
      "ADMINISTRACAO_NAO_CANCELAVEL",
      "Somente doses marcadas como tomadas podem ser canceladas.",
      409,
    );
  }

  await client.query("delete from administracoes_medicamentos where id = $1", [
    administracaoId,
  ]);

  const quantidadeDose = Number(administracao.quantidade_dose);
  if (Number.isFinite(quantidadeDose) && quantidadeDose > 0) {
    await client.query(
      `
        update medicamentos
        set quantidade_estoque = coalesce(quantidade_estoque, 0) + $1
        where id = $2
      `,
      [quantidadeDose, medicamentoId],
    );
  }

  const administracaoCancelada = {
    ...administracao,
    status: "cancelado",
    cancelado_em: new Date().toISOString(),
  };
  await client.query(
    `
      insert into historico_alteracoes (
        idoso_id,
        usuario_id,
        acao,
        tipo_entidade,
        entidade_id,
        dados_anteriores,
        dados_novos
      )
      values ($1, $2, $3, $4, $5, $6, $7)
    `,
    [
      idosoId,
      usuarioId,
      "cancelar_administracao",
      "administracoes_medicamentos",
      administracaoId,
      JSON.stringify(administracao),
      JSON.stringify(administracaoCancelada),
    ],
  );
  return administracaoCancelada;
};

const FUSO_CUIDADO_OFFSET = "-03:00";

const NOMES_DIAS_SEMANA = [
  "Domingo",
  "Segunda",
  "Terça",
  "Quarta",
  "Quinta",
  "Sexta",
  "Sábado",
];

const somarDiasDataChave = (dataChave: string, dias: number) => {
  const [ano, mes, dia] = dataChave.split("-").map(Number);
  const date = new Date(Date.UTC(ano, (mes || 1) - 1, dia || 1, 12));
  date.setUTCDate(date.getUTCDate() + dias);
  return `${date.getUTCFullYear().toString().padStart(4, "0")}-${(
    date.getUTCMonth() + 1
  )
    .toString()
    .padStart(2, "0")}-${date.getUTCDate().toString().padStart(2, "0")}`;
};

const diaSemanaDataChave = (dataChave: string) => {
  const [ano, mes, dia] = dataChave.split("-").map(Number);
  const date = new Date(Date.UTC(ano, (mes || 1) - 1, dia || 1, 12));
  return date.getUTCDay();
};

const dataHoraCuidadoParaDate = (dataChave: string, horaMinuto: string) =>
  new Date(`${dataChave}T${horaMinuto}:00${FUSO_CUIDADO_OFFSET}`);

const dataDateColumnChave = (date: Date) =>
  `${date.getUTCFullYear().toString().padStart(4, "0")}-${(
    date.getUTCMonth() + 1
  )
    .toString()
    .padStart(2, "0")}-${date.getUTCDate().toString().padStart(2, "0")}`;

const diaEhValidoNaData = (
  dataChave: string,
  tipoFrequencia: string,
  diasSemana: string | null,
  dataAncora: Date | null,
): boolean => {
  if (tipoFrequencia === "semanal" && diasSemana) {
    const dias = new Set(diasSemana.split(",").map((item) => item.trim()));
    return dias.has(NOMES_DIAS_SEMANA[diaSemanaDataChave(dataChave)]);
  }

  if (tipoFrequencia === "alternado") {
    if (!dataAncora) return true;
    const [ano, mes, dia] = dataChave.split("-").map(Number);
    const diaCandidataUtc = Date.UTC(ano, (mes || 1) - 1, dia || 1);
    const [anoAncora, mesAncora, diaAncora] = dataDateColumnChave(dataAncora)
      .split("-")
      .map(Number);
    const diaAncoraUtc = Date.UTC(
      anoAncora,
      (mesAncora || 1) - 1,
      diaAncora || 1,
    );
    const diffDias = Math.round(
      (diaCandidataUtc - diaAncoraUtc) / (1000 * 60 * 60 * 24),
    );
    return diffDias % 2 === 0;
  }

  return true;
};

const jaAdministradoEm = (
  dataChave: string,
  horaMinuto: string,
  administracoes: { horarioPrevisto: Date }[],
) =>
  administracoes.some((administracao) => {
    const previsto = administracao.horarioPrevisto;
    return horarioPrevistoCorresponde(dataChave, horaMinuto, previsto);
  });

const dataLocalChave = (date: Date) =>
  `${date.getFullYear().toString().padStart(4, "0")}-${(date.getMonth() + 1)
    .toString()
    .padStart(2, "0")}-${date.getDate().toString().padStart(2, "0")}`;

const horarioLocalChave = (date: Date) =>
  `${date.getHours().toString().padStart(2, "0")}:${date
    .getMinutes()
    .toString()
    .padStart(2, "0")}`;

const horarioUtcChave = (date: Date) =>
  `${date.getUTCHours().toString().padStart(2, "0")}:${date
    .getUTCMinutes()
    .toString()
    .padStart(2, "0")}`;

const dataUtcChave = (date: Date) =>
  `${date.getUTCFullYear().toString().padStart(4, "0")}-${(
    date.getUTCMonth() + 1
  )
    .toString()
    .padStart(2, "0")}-${date.getUTCDate().toString().padStart(2, "0")}`;

const formatadorSaoPaulo = new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/Sao_Paulo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

const partesSaoPaulo = (date: Date) => {
  const parts = formatadorSaoPaulo.formatToParts(date);
  const valor = (type: string) =>
    parts.find((part) => part.type === type)?.value ?? "";
  return {
    data: `${valor("year")}-${valor("month")}-${valor("day")}`,
    horario: `${valor("hour")}:${valor("minute")}`,
  };
};

const horarioPrevistoCorresponde = (
  dataChave: string,
  horaMinuto: string,
  previsto: Date,
) => {
  const partesPrevistoSaoPaulo = partesSaoPaulo(previsto);

  return (
    (dataLocalChave(previsto) === dataChave &&
      horarioLocalChave(previsto) === horaMinuto) ||
    (dataUtcChave(previsto) === dataChave &&
      horarioUtcChave(previsto) === horaMinuto) ||
    (partesPrevistoSaoPaulo.data === dataChave &&
      partesPrevistoSaoPaulo.horario === horaMinuto)
  );
};

const administracaoNoDia = (
  administracao: { horarioPrevisto: Date },
  dataChave: string,
) => {
  const previsto = administracao.horarioPrevisto;
  return (
    dataLocalChave(previsto) === dataChave ||
    dataUtcChave(previsto) === dataChave ||
    partesSaoPaulo(previsto).data === dataChave
  );
};

const chavesDataHoraPossiveis = (date: Date) => {
  const sp = partesSaoPaulo(date);
  return new Set([
    `${dataLocalChave(date)} ${horarioLocalChave(date)}`,
    `${dataUtcChave(date)} ${horarioUtcChave(date)}`,
    `${sp.data} ${sp.horario}`,
  ]);
};

const mesmaDataHoraPossivel = (left: Date, right: Date) => {
  const leftKeys = chavesDataHoraPossiveis(left);
  const rightKeys = chavesDataHoraPossiveis(right);
  return [...leftKeys].some((key) => rightKeys.has(key));
};

const horarioPrevistoCanonico = async (
  client: PoolClient,
  medicamentoId: string,
  horarioPrevisto: Date,
  dataAncora: Date | null,
) => {
  const horariosResult = await client.query<{
    horario: string;
    tipo_frequencia: string | null;
    dias_semana: string | null;
  }>(
    `
      select horario, tipo_frequencia, dias_semana
      from horarios_medicamentos
      where medicamento_id = $1
    `,
    [medicamentoId],
  );

  const datasPossiveis = new Set([
    partesSaoPaulo(horarioPrevisto).data,
    dataUtcChave(horarioPrevisto),
    dataLocalChave(horarioPrevisto),
  ]);

  for (const row of horariosResult.rows) {
    const horaFormatada = formatarHorario(row.horario);
    if (!horaFormatada) continue;

    for (const dataChave of datasPossiveis) {
      if (
        diaEhValidoNaData(
          dataChave,
          row.tipo_frequencia ?? "diaria",
          row.dias_semana,
          dataAncora,
        ) &&
        horarioPrevistoCorresponde(dataChave, horaFormatada, horarioPrevisto)
      ) {
        return dataHoraCuidadoParaDate(dataChave, horaFormatada);
      }
    }
  }

  return horarioPrevisto;
};

const proximaOcorrencia = (
  horaMinuto: string,
  agora: Date,
  tipoFrequencia: string,
  diasSemana: string | null,
  dataAncora: Date | null,
  administracoesHoje: { horarioPrevisto: Date }[],
): { data: Date; atrasado: boolean } | null => {
  const dataHoje = partesSaoPaulo(agora).data;

  for (let offset = 0; offset < 15; offset++) {
    const dataCandidata = somarDiasDataChave(dataHoje, offset);
    const candidata = dataHoraCuidadoParaDate(dataCandidata, horaMinuto);

    if (
      !diaEhValidoNaData(dataCandidata, tipoFrequencia, diasSemana, dataAncora)
    ) {
      continue;
    }

    const atrasoMs = agora.getTime() - candidata.getTime();

    if (atrasoMs < 0) {
      return { data: candidata, atrasado: false };
    }

    if (!jaAdministradoEm(dataCandidata, horaMinuto, administracoesHoje)) {
      return { data: candidata, atrasado: atrasoMs > TOLERANCIA_ATRASO_MS };
    }
  }

  return null;
};

const formatarHorario = (valor: unknown) => {
  if (!valor) return null;
  return String(valor).slice(0, 5);
};

const TOLERANCIA_ATRASO_MINUTOS = 30;
const TOLERANCIA_ATRASO_MS = TOLERANCIA_ATRASO_MINUTOS * 60 * 1000;

const rotuloStatusAdministracao = (
  status: string,
  administradoEm?: unknown,
  horarioPrevisto?: unknown,
) => {
  switch (status) {
    case "tomado": {
      if (administradoEm && horarioPrevisto) {
        const administrado = new Date(String(administradoEm));
        const previsto = new Date(String(horarioPrevisto));
        const atrasoMinutos =
          (administrado.getTime() - previsto.getTime()) / 60000;
        if (
          !Number.isNaN(atrasoMinutos) &&
          atrasoMinutos > TOLERANCIA_ATRASO_MINUTOS
        ) {
          return {
            descricao: "deu o remédio com atraso",
            texto: "Tomado com atraso",
            cor: "alerta" as const,
          };
        }
      }
      return {
        descricao: "marcou como tomado",
        texto: "Tomado",
        cor: "normal" as const,
      };
    }
    case "atrasado":
      return {
        descricao: "registrou atraso na dose",
        texto: "Atrasado",
        cor: "alerta" as const,
      };
    case "nao_tomou":
      return {
        descricao: "registrou dose não tomada",
        texto: "Não tomou",
        cor: "alerta" as const,
      };
    case "recusou":
      return {
        descricao: "registrou recusa da dose",
        texto: "Recusou",
        cor: "alerta" as const,
      };
    case "cancelado":
      return {
        descricao: "cancelou a administra\u00e7\u00e3o",
        texto: "Cancelado",
        cor: "atualizado" as const,
      };
    default:
      return {
        descricao: "registrou administração",
        texto: "Pendente",
        cor: "neutro" as const,
      };
  }
};

export const medicamentosService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "nome asc",
    });
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarMedicamentoInput) {
    const medicamento = await insertRow<
      CriarMedicamentoInput,
      Record<string, unknown>
    >(table, { ...input, ativo: input.ativo ?? true }, fields);
    await registrarHistorico({
      usuarioId: input.registradoPorId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(medicamento.id),
      dadosNovos: medicamento,
    });
    return medicamento;
  },

  async atualizar(id: string, input: AtualizarMedicamentoInput) {
    const anterior = await this.buscarPorId(id);
    const atualizado = await updateRow<
      AtualizarMedicamentoInput,
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

  async remover(id: string, usuarioId?: string) {
    const anterior = await this.buscarPorId(id);
    await deleteRow(table, id, ...notFound);
    await registrarHistorico({
      usuarioId,
      idosoId: String(anterior.idoso_id ?? ""),
      acao: "remover",
      tipoEntidade: table,
      entidadeId: id,
      dadosAnteriores: anterior,
    });
  },

  async listarHorarios(medicamentoId: string) {
    const result = await getPool().query(
      "select * from horarios_medicamentos where medicamento_id = $1 order by horario",
      [medicamentoId],
    );
    return result.rows;
  },

  async criarHorario(
    medicamentoId: string,
    input: CriarHorarioMedicamentoInput,
  ) {
    return insertRow<Record<string, unknown>, Record<string, unknown>>(
      "horarios_medicamentos",
      { ...input, medicamentoId },
      {
        medicamentoId: "medicamento_id",
        tipoFrequencia: "tipo_frequencia",
        horario: "horario",
        quantidadeDose: "quantidade_dose",
        unidadeDose: "unidade_dose",
        diasSemana: "dias_semana",
      },
    );
  },

  async substituirHorarios(
    medicamentoId: string,
    input: SubstituirHorariosMedicamentoInput,
  ) {
    const medicamento = await this.buscarPorId(medicamentoId);
    const pool = getPool();
    const client = await pool.connect();
    const tipoFrequencia = input.frequenciaTipo;
    const diasSemana =
      tipoFrequencia === "semanal" && input.diasSemana?.length
        ? input.diasSemana.join(",")
        : null;

    try {
      await client.query("begin");
      await client.query(
        "delete from horarios_medicamentos where medicamento_id = $1",
        [medicamentoId],
      );

      for (const horario of input.horarios) {
        await client.query(
          `
            insert into horarios_medicamentos (
              medicamento_id, tipo_frequencia, horario, quantidade_dose, unidade_dose, dias_semana
            )
            values ($1, $2, $3, $4, $5, $6)
          `,
          [
            medicamentoId,
            tipoFrequencia,
            horario.horario,
            horario.quantidadeDose ?? null,
            horario.unidadeDose ?? null,
            diasSemana,
          ],
        );
      }

      await client.query("commit");
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }

    const horarios = await this.listarHorarios(medicamentoId);

    const registradoPorId = await resolverUsuarioRegistroId(
      input.registradoPorId,
    );
    await registrarHistorico({
      usuarioId: registradoPorId,
      idosoId: String(medicamento.idoso_id ?? ""),
      acao: "atualizar",
      tipoEntidade: "horarios_medicamentos",
      entidadeId: medicamentoId,
      dadosNovos: { medicamentoId, horarios },
    });

    return horarios;
  },

  async listarAdministracoes(medicamentoId: string) {
    const result = await getPool().query(
      `
        select *
        from administracoes_medicamentos
        where medicamento_id = $1
        order by coalesce(administrado_em, horario_previsto) desc
        limit 60
      `,
      [medicamentoId],
    );
    return result.rows;
  },

  async resumo(idosoId: string) {
    const medicamentosResult = await getPool().query<Record<string, unknown>>(
      `
        select *
        from medicamentos
        where idoso_id = $1
          and ativo = true
          and (data_fim is null or data_fim >= current_date)
        order by nome asc
      `,
      [idosoId],
    );

    const agora = new Date();
    const dataHojeChave = partesSaoPaulo(agora).data;
    const inicioDeHoje = dataHoraCuidadoParaDate(dataHojeChave, "00:00");
    const fimDeHoje = dataHoraCuidadoParaDate(
      somarDiasDataChave(dataHojeChave, 1),
      "00:00",
    );
    const inicioBuscaAdministracoes = new Date(inicioDeHoje);
    inicioBuscaAdministracoes.setDate(inicioBuscaAdministracoes.getDate() - 1);
    const fimBuscaAdministracoes = new Date(fimDeHoje);
    fimBuscaAdministracoes.setDate(fimBuscaAdministracoes.getDate() + 1);
    const medicamentos = [];
    let proximoMedicamento: Record<string, unknown> | null = null;
    let proximaData: Date | null = null;
    let proximoAtrasado = false;

    for (const medicamento of medicamentosResult.rows) {
      const horariosResult = await getPool().query<{
        horario: string;
        tipo_frequencia: string | null;
        dias_semana: string | null;
        quantidade_dose: number | string | null;
        unidade_dose: string | null;
      }>(
        `
          select horario, tipo_frequencia, dias_semana, quantidade_dose, unidade_dose
          from horarios_medicamentos
          where medicamento_id = $1
        `,
        [medicamento.id],
      );

      const administracoesResult = await getPool().query<{
        horarioPrevisto: Date;
        status: string;
        administradoEm: Date | null;
      }>(
        `
          select
            horario_previsto as "horarioPrevisto",
            status,
            administrado_em as "administradoEm"
          from administracoes_medicamentos
          where medicamento_id = $1
            and horario_previsto >= $2
            and horario_previsto < $3
        `,
        [
          medicamento.id,
          inicioBuscaAdministracoes.toISOString(),
          fimBuscaAdministracoes.toISOString(),
        ],
      );
      const administracoesHoje = administracoesResult.rows.filter((item) =>
        administracaoNoDia(item, dataHojeChave),
      );

      const dataAncora = medicamento.data_inicio
        ? new Date(String(medicamento.data_inicio))
        : null;

      let proximoHorario: string | null = null;
      let proximaOcorrenciaMedicamento: Date | null = null;
      let atrasado = false;

      for (const row of horariosResult.rows) {
        const horaFormatada = formatarHorario(row.horario);
        if (!horaFormatada) continue;
        const ocorrencia = proximaOcorrencia(
          horaFormatada,
          agora,
          row.tipo_frequencia ?? "diaria",
          row.dias_semana,
          dataAncora,
          administracoesHoje,
        );
        if (!ocorrencia) continue;
        const maisUrgente =
          !proximaOcorrenciaMedicamento ||
          (ocorrencia.atrasado && !atrasado) ||
          (ocorrencia.atrasado === atrasado &&
            ocorrencia.data < proximaOcorrenciaMedicamento);
        if (maisUrgente) {
          proximaOcorrenciaMedicamento = ocorrencia.data;
          proximoHorario = horaFormatada;
          atrasado = ocorrencia.atrasado;
        }
      }
      const proximaOcorrenciaHoje =
        proximaOcorrenciaMedicamento &&
        partesSaoPaulo(proximaOcorrenciaMedicamento).data === dataHojeChave;
      const proximoHorarioHoje = proximaOcorrenciaHoje ? proximoHorario : null;

      const item = {
        id: medicamento.id,
        nome: medicamento.nome,
        dosagem: medicamento.dosagem,
        formato: medicamento.formato,
        dataInicio: medicamento.data_inicio,
        dataFim: medicamento.data_fim,
        quantidadeEstoque:
          medicamento.quantidade_estoque == null
            ? null
            : Number(medicamento.quantidade_estoque),
        unidadeEstoque: medicamento.unidade_estoque,
        alertaEstoqueBaixo:
          medicamento.alerta_estoque_baixo == null
            ? null
            : Number(medicamento.alerta_estoque_baixo),
        proximoHorario: proximoHorarioHoje,
        proximoHorarioPrevisto: proximaOcorrenciaHoje
          ? proximaOcorrenciaMedicamento?.toISOString()
          : null,
        proximoAtrasado: proximaOcorrenciaHoje ? atrasado : false,
        statusHoje: proximoHorarioHoje
          ? atrasado
            ? "atrasado"
            : "pendente"
          : administracoesHoje.length > 0
            ? "dado"
            : "sem_pendencia",
        dosesAdministradasHoje: administracoesHoje.length,
        totalHorarios: horariosResult.rows.length,
        horarios: horariosResult.rows,
      };

      medicamentos.push(item);

      const substituiProximo =
        proximaOcorrenciaHoje &&
        proximaOcorrenciaMedicamento &&
        (!proximaData ||
          (atrasado && !proximoAtrasado) ||
          (atrasado === proximoAtrasado &&
            proximaOcorrenciaMedicamento < proximaData));

      if (substituiProximo && proximaOcorrenciaMedicamento) {
        proximaData = proximaOcorrenciaMedicamento;
        proximoMedicamento = item;
        proximoAtrasado = atrasado;
      }
    }

    return {
      proximoMedicamento,
      medicamentos,
      totalMedicamentos: medicamentos.length,
    };
  },

  async historico(
    idosoId: string,
    dataReferencia?: string,
    periodo: PeriodoMedicamentos = "dia",
  ): Promise<HistoricoMedicamentoEntrada[]> {
    const referencia = parseLocalDate(dataReferencia);
    const { start: inicio, endExclusive: fim } = periodRange(
      referencia,
      periodo,
    );

    const result = await getPool().query<{
      id: string;
      acao: string;
      tipoEntidade: string;
      entidadeId: string;
      dadosAnteriores: Record<string, unknown> | null;
      dadosNovos: Record<string, unknown> | null;
      criadoEm: Date;
      usuarioNome: string | null;
    }>(
      `
        select
          h.id,
          h.acao,
          h.tipo_entidade as "tipoEntidade",
          h.entidade_id as "entidadeId",
          h.dados_anteriores as "dadosAnteriores",
          h.dados_novos as "dadosNovos",
          h.criado_em as "criadoEm",
          coalesce(u.nome, 'Cuidador') as "usuarioNome"
        from historico_alteracoes h
        left join usuarios u on u.id = h.usuario_id
        where h.idoso_id = $1
          and h.tipo_entidade in ('medicamentos', 'administracoes_medicamentos', 'horarios_medicamentos')
          and h.criado_em >= $2
          and h.criado_em < $3
        order by h.criado_em desc
        limit 100
      `,
      [idosoId, inicio.toISOString(), fim.toISOString()],
    );

    const medicamentoIds = new Set<string>();
    for (const row of result.rows) {
      if (row.tipoEntidade === "medicamentos") {
        medicamentoIds.add(row.entidadeId);
        continue;
      }
      const dados = row.dadosNovos ?? row.dadosAnteriores;
      const medId = dados?.medicamentoId ?? dados?.medicamento_id;
      if (medId) medicamentoIds.add(String(medId));
    }

    const nomesPorId = new Map<string, string>();
    if (medicamentoIds.size > 0) {
      const nomesResult = await getPool().query<{
        id: string;
        nome: string;
      }>("select id, nome from medicamentos where id = any($1::uuid[])", [
        Array.from(medicamentoIds),
      ]);
      for (const row of nomesResult.rows) {
        nomesPorId.set(row.id, row.nome);
      }
    }

    return result.rows.map((row) => {
      const dados = row.dadosNovos ?? row.dadosAnteriores ?? {};
      const medId =
        row.tipoEntidade === "medicamentos"
          ? row.entidadeId
          : String(dados.medicamentoId ?? dados.medicamento_id ?? "");
      const medicamentoNome = nomesPorId.get(medId) ?? "Medicamento";

      if (row.tipoEntidade === "administracoes_medicamentos") {
        const dadosAdministracao = row.dadosNovos ?? {};
        const status = String(dadosAdministracao.status ?? "").toLowerCase();
        const administradoEm = dadosAdministracao.administrado_em;
        const horarioPrevisto = dadosAdministracao.horario_previsto;
        const rotulo = rotuloStatusAdministracao(
          status,
          administradoEm,
          horarioPrevisto,
        );
        const dataHoraRegistro = administradoEm ?? horarioPrevisto;
        return {
          id: row.id,
          usuarioNome: row.usuarioNome ?? "Cuidador",
          medicamentoNome,
          descricao: rotulo.descricao,
          dataHora: dataHoraRegistro
            ? new Date(String(dataHoraRegistro)).toISOString()
            : row.criadoEm.toISOString(),
          badge: { texto: rotulo.texto, cor: rotulo.cor },
        };
      }

      if (row.tipoEntidade === "horarios_medicamentos") {
        return {
          id: row.id,
          usuarioNome: row.usuarioNome ?? "Cuidador",
          medicamentoNome,
          descricao: "reagendou horário",
          dataHora: row.criadoEm.toISOString(),
          badge: { texto: "Pendente", cor: "neutro" as const },
        };
      }

      if (row.acao === "criar") {
        return {
          id: row.id,
          usuarioNome: row.usuarioNome ?? "Cuidador",
          medicamentoNome,
          descricao: "registrou medicamento",
          dataHora: row.criadoEm.toISOString(),
          badge: { texto: "Pendente", cor: "neutro" as const },
        };
      }

      if (row.acao === "remover") {
        return {
          id: row.id,
          usuarioNome: row.usuarioNome ?? "Cuidador",
          medicamentoNome,
          descricao: "removeu medicamento",
          dataHora: row.criadoEm.toISOString(),
          badge: { texto: "Removido", cor: "alerta" as const },
        };
      }

      const dosagemAnterior = row.dadosAnteriores?.dosagem;
      const dosagemNova = row.dadosNovos?.dosagem;
      const descricao =
        dosagemAnterior !== dosagemNova
          ? "atualizou dosagem"
          : "atualizou medicamento";

      return {
        id: row.id,
        usuarioNome: row.usuarioNome ?? "Cuidador",
        medicamentoNome,
        descricao,
        dataHora: row.criadoEm.toISOString(),
        badge: { texto: "Atualizado", cor: "atualizado" as const },
      };
    });
  },

  async registrarAdministracao(
    medicamentoId: string,
    input: RegistrarAdministracaoInput,
  ) {
    const registradoPorId = await resolverUsuarioRegistroId(
      input.registradoPorId,
    );
    const pool = getPool();
    const client = await pool.connect();

    try {
      await client.query("begin");
      const medicamentoResult = await client.query<{
        id: string;
        idoso_id: string;
        data_inicio: Date | null;
      }>(
        `
          select id, idoso_id, data_inicio
          from medicamentos
          where id = $1
          for update
        `,
        [medicamentoId],
      );

      const medicamento = medicamentoResult.rows[0];
      if (!medicamento || medicamento.idoso_id !== input.idosoId) {
        throw new AppError(
          "MEDICAMENTO_NAO_ENCONTRADO",
          "Medicamento não encontrado para esta ficha.",
          404,
        );
      }

      const horarioPrevistoOriginal = new Date(input.horarioPrevisto);
      const horarioPrevisto = await horarioPrevistoCanonico(
        client,
        medicamentoId,
        horarioPrevistoOriginal,
        medicamento.data_inicio,
      );
      await client.query(
        "select pg_advisory_xact_lock(hashtext($1), hashtext($2))",
        [medicamentoId, horarioPrevisto.toISOString()],
      );
      const inicioBuscaDuplicado = new Date(horarioPrevisto);
      inicioBuscaDuplicado.setDate(inicioBuscaDuplicado.getDate() - 1);
      const fimBuscaDuplicado = new Date(horarioPrevisto);
      fimBuscaDuplicado.setDate(fimBuscaDuplicado.getDate() + 1);
      const duplicadoResult = await client.query<{
        id: string;
        horarioPrevisto: Date;
      }>(
        `
          select id, horario_previsto as "horarioPrevisto"
          from administracoes_medicamentos
          where medicamento_id = $1
            and idoso_id = $2
            and horario_previsto >= $3
            and horario_previsto < $4
        `,
        [
          medicamentoId,
          input.idosoId,
          inicioBuscaDuplicado.toISOString(),
          fimBuscaDuplicado.toISOString(),
        ],
      );

      const horarioCanonicoPartes = partesSaoPaulo(horarioPrevisto);
      const duplicado = duplicadoResult.rows.some(
        (item) =>
          mesmaDataHoraPossivel(item.horarioPrevisto, horarioPrevisto) ||
          horarioPrevistoCorresponde(
            horarioCanonicoPartes.data,
            horarioCanonicoPartes.horario,
            item.horarioPrevisto,
          ),
      );

      if (duplicado) {
        throw new AppError(
          "DOSE_JA_ADMINISTRADA",
          "Esta medicacao ja foi registrada como administrada neste horario.",
          409,
        );
      }

      const administracaoResult = await client.query<Record<string, unknown>>(
        `
          insert into administracoes_medicamentos (
            medicamento_id,
            idoso_id,
            horario_previsto,
            administrado_em,
            status,
            quantidade_dose,
            registrado_por_id,
            observacoes
          )
          values ($1, $2, $3, $4, $5, $6, $7, $8)
          returning *
        `,
        [
          medicamentoId,
          input.idosoId,
          horarioPrevisto.toISOString(),
          input.administradoEm ?? null,
          input.status,
          input.quantidadeDose ?? null,
          registradoPorId,
          input.observacoes ?? null,
        ],
      );
      const administracao = administracaoResult.rows[0];

      if (input.status === "tomado" && input.quantidadeDose) {
        await client.query(
          `
            update medicamentos
            set quantidade_estoque = greatest(coalesce(quantidade_estoque, 0) - $1, 0)
            where id = $2
          `,
          [input.quantidadeDose, medicamentoId],
        );
      }

      await client.query(
        `
          insert into historico_alteracoes (
            idoso_id,
            usuario_id,
            acao,
            tipo_entidade,
            entidade_id,
            dados_anteriores,
            dados_novos
          )
          values ($1, $2, $3, $4, $5, $6, $7)
        `,
        [
          input.idosoId,
          registradoPorId,
          "registrar_administracao",
          "administracoes_medicamentos",
          String(administracao.id),
          null,
          JSON.stringify(administracao),
        ],
      );

      await client.query("commit");
      return administracao;
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }
  },

  async cancelarAdministracao(
    medicamentoId: string,
    administracaoId: string,
    idosoId: string,
    usuarioId: string,
  ) {
    const pool = getPool();
    const client = await pool.connect();

    try {
      await client.query("begin");
      const donoId = await buscarDonoFicha(client, idosoId);
      if (donoId !== usuarioId) {
        throw new AppError(
          "CANCELAMENTO_EXIGE_RESPONSAVEL",
          "Somente o responsável pela ficha pode cancelar a dose.",
          403,
        );
      }
      const administracaoCancelada = await cancelarAdministracaoComCliente(
        client,
        medicamentoId,
        administracaoId,
        idosoId,
        usuarioId,
      );
      await client.query("commit");
      return administracaoCancelada;
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }
  },

  async solicitarCancelamentoAdministracao(
    medicamentoId: string,
    administracaoId: string,
    idosoId: string,
    solicitanteId: string,
  ) {
    await garantirTabelaSolicitacoesCancelamento();
    const client = await getPool().connect();
    let push:
      | {
          responsavelId: string;
          solicitacaoId: string;
          medicamentoNome: string;
          solicitanteNome: string;
        }
      | undefined;

    try {
      await client.query("begin");
      const responsavelId = await buscarDonoFicha(client, idosoId);
      if (responsavelId === solicitanteId) {
        throw new AppError(
          "RESPONSAVEL_CANCELA_DIRETAMENTE",
          "O responsável pode cancelar a dose diretamente.",
          409,
        );
      }
      if (!(await podeEditarMedicacoes(client, idosoId, solicitanteId))) {
        throw new AppError(
          "SEM_PERMISSAO_EDITAR_MEDICAMENTOS",
          "Você não tem permissão para editar medicamentos.",
          403,
        );
      }

      const doseResult = await client.query<{
        medicamento_nome: string;
        solicitante_nome: string;
      }>(
        `
          select m.nome as medicamento_nome, u.nome as solicitante_nome
          from administracoes_medicamentos am
          join medicamentos m on m.id = am.medicamento_id
          join usuarios u on u.id = $4
          where am.id = $1
            and am.medicamento_id = $2
            and am.idoso_id = $3
            and lower(am.status) = 'tomado'
          limit 1
        `,
        [administracaoId, medicamentoId, idosoId, solicitanteId],
      );
      const dose = doseResult.rows[0];
      if (!dose) {
        throw new AppError(
          "ADMINISTRACAO_NAO_CANCELAVEL",
          "A dose não foi encontrada ou não pode mais ser cancelada.",
          409,
        );
      }

      const existente = await client.query<Record<string, unknown>>(
        `
          select *
          from solicitacoes_cancelamento_medicamento
          where administracao_id = $1 and status = 'pendente'
          limit 1
        `,
        [administracaoId],
      );
      if (existente.rows[0]) {
        await client.query("commit");
        return existente.rows[0];
      }

      const result = await client.query<Record<string, unknown>>(
        `
          insert into solicitacoes_cancelamento_medicamento (
            idoso_id,
            medicamento_id,
            administracao_id,
            solicitante_id,
            responsavel_id
          )
          values ($1, $2, $3, $4, $5)
          returning *
        `,
        [idosoId, medicamentoId, administracaoId, solicitanteId, responsavelId],
      );
      const solicitacao = result.rows[0];
      const solicitacaoId = String(solicitacao.id);
      const mensagem = `${dose.solicitante_nome} solicitou o cancelamento da dose de ${dose.medicamento_nome}.`;
      await client.query(
        `
          insert into notificacoes (
            idoso_id,
            usuario_id,
            titulo,
            mensagem,
            tipo_notificacao,
            tipo_entidade_relacionada,
            entidade_relacionada_id,
            programado_para
          )
          values ($1, $2, $3, $4, $5, $6, $7, now())
        `,
        [
          idosoId,
          responsavelId,
          "Cancelamento de medicação",
          mensagem,
          "solicitacao_cancelamento_medicamento",
          "solicitacoes_cancelamento_medicamento",
          solicitacaoId,
        ],
      );
      await client.query("commit");
      push = {
        responsavelId,
        solicitacaoId,
        medicamentoNome: dose.medicamento_nome,
        solicitanteNome: dose.solicitante_nome,
      };
      return solicitacao;
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
      if (push) {
        void enviarPushMedicamento({
          destinatarioId: push.responsavelId,
          titulo: "Cancelamento de medicação",
          mensagem: `${push.solicitanteNome} quer cancelar a dose de ${push.medicamentoNome}.`,
          idosoId,
          solicitacaoId: push.solicitacaoId,
        }).catch(() => undefined);
      }
    }
  },

  async listarSolicitacoesCancelamento(idosoId: string, responsavelId: string) {
    await garantirTabelaSolicitacoesCancelamento();
    const client = await getPool().connect();
    try {
      const donoId = await buscarDonoFicha(client, idosoId);
      if (donoId !== responsavelId) {
        throw new AppError(
          "APENAS_RESPONSAVEL_LISTA_SOLICITACOES",
          "Somente o responsável pode consultar estas solicitações.",
          403,
        );
      }
      const result = await client.query(
        `
          select
            s.id,
            s.idoso_id as "idosoId",
            s.medicamento_id as "medicamentoId",
            s.administracao_id as "administracaoId",
            s.solicitante_id as "solicitanteId",
            u.nome as "solicitanteNome",
            m.nome as "medicamentoNome",
            m.dosagem,
            s.status,
            s.criado_em as "criadoEm"
          from solicitacoes_cancelamento_medicamento s
          join usuarios u on u.id = s.solicitante_id
          join medicamentos m on m.id = s.medicamento_id
          where s.idoso_id = $1
            and s.responsavel_id = $2
            and s.status = 'pendente'
          order by s.criado_em asc
        `,
        [idosoId, responsavelId],
      );
      return result.rows;
    } finally {
      client.release();
    }
  },

  async responderSolicitacaoCancelamento(
    solicitacaoId: string,
    aprovar: boolean,
    responsavelId: string,
  ) {
    await garantirTabelaSolicitacoesCancelamento();
    const client = await getPool().connect();
    let notificacaoResposta:
      | { destinatarioId: string; idosoId: string; medicamentoNome: string }
      | undefined;

    try {
      await client.query("begin");
      const result = await client.query<{
        id: string;
        idoso_id: string;
        medicamento_id: string;
        administracao_id: string;
        solicitante_id: string;
        responsavel_id: string;
        status: string;
        medicamento_nome: string;
      }>(
        `
          select s.*, m.nome as medicamento_nome
          from solicitacoes_cancelamento_medicamento s
          join medicamentos m on m.id = s.medicamento_id
          where s.id = $1
          for update of s
        `,
        [solicitacaoId],
      );
      const solicitacao = result.rows[0];
      if (!solicitacao || solicitacao.responsavel_id !== responsavelId) {
        throw new AppError(
          "SOLICITACAO_NAO_ENCONTRADA",
          "Solicitação de cancelamento não encontrada.",
          404,
        );
      }
      if (solicitacao.status !== "pendente") {
        throw new AppError(
          "SOLICITACAO_JA_RESPONDIDA",
          "Esta solicitação já foi respondida.",
          409,
        );
      }

      if (aprovar) {
        await cancelarAdministracaoComCliente(
          client,
          solicitacao.medicamento_id,
          solicitacao.administracao_id,
          solicitacao.idoso_id,
          responsavelId,
        );
      }
      const status = aprovar ? "aprovada" : "recusada";
      const atualizado = await client.query<Record<string, unknown>>(
        `
          update solicitacoes_cancelamento_medicamento
          set status = $2,
              respondido_por_id = $3,
              respondido_em = now()
          where id = $1
          returning *
        `,
        [solicitacaoId, status, responsavelId],
      );
      await client.query(
        `
          update notificacoes
          set lido_em = coalesce(lido_em, now())
          where tipo_entidade_relacionada = 'solicitacoes_cancelamento_medicamento'
            and entidade_relacionada_id = $1
            and usuario_id = $2
        `,
        [solicitacaoId, responsavelId],
      );
      const mensagem = aprovar
        ? `O cancelamento da dose de ${solicitacao.medicamento_nome} foi aprovado.`
        : `O cancelamento da dose de ${solicitacao.medicamento_nome} foi recusado.`;
      await client.query(
        `
          insert into notificacoes (
            idoso_id,
            usuario_id,
            titulo,
            mensagem,
            tipo_notificacao,
            tipo_entidade_relacionada,
            entidade_relacionada_id,
            programado_para
          )
          values ($1, $2, $3, $4, $5, $6, $7, now())
        `,
        [
          solicitacao.idoso_id,
          solicitacao.solicitante_id,
          "Solicitação de medicação respondida",
          mensagem,
          "resposta_cancelamento_medicamento",
          "solicitacoes_cancelamento_medicamento",
          solicitacaoId,
        ],
      );
      await client.query("commit");
      notificacaoResposta = {
        destinatarioId: solicitacao.solicitante_id,
        idosoId: solicitacao.idoso_id,
        medicamentoNome: solicitacao.medicamento_nome,
      };
      return atualizado.rows[0];
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
      if (notificacaoResposta) {
        void enviarPushMedicamento({
          destinatarioId: notificacaoResposta.destinatarioId,
          titulo: "Solicitação respondida",
          mensagem: aprovar
            ? `O cancelamento de ${notificacaoResposta.medicamentoNome} foi aprovado.`
            : `O cancelamento de ${notificacaoResposta.medicamentoNome} foi recusado.`,
          idosoId: notificacaoResposta.idosoId,
          solicitacaoId,
        }).catch(() => undefined);
      }
    }
  },
};
