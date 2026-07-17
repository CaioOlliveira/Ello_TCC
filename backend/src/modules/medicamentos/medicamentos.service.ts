import { registrarHistorico } from "../../database/audit.js";
import { getPool } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
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

const startOfDay = (date: Date) => {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
};

const inicioDoPeriodoHistorico = (
  referencia: Date,
  periodo: PeriodoMedicamentos,
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

const NOMES_DIAS_SEMANA = [
  "Domingo",
  "Segunda",
  "Terça",
  "Quarta",
  "Quinta",
  "Sexta",
  "Sábado",
];

const diaEhValido = (
  candidata: Date,
  tipoFrequencia: string,
  diasSemana: string | null,
  dataAncora: Date | null,
): boolean => {
  if (tipoFrequencia === "semanal" && diasSemana) {
    const dias = new Set(diasSemana.split(",").map((item) => item.trim()));
    return dias.has(NOMES_DIAS_SEMANA[candidata.getDay()]);
  }

  if (tipoFrequencia === "alternado") {
    if (!dataAncora) return true;

    // data_inicio vem do banco como uma coluna "date" (sem hora), que o
    // driver do Postgres materializa como meia-noite UTC. Comparamos os
    // componentes de calendario (candidata em hora local, ancora em UTC)
    // em vez de subtrair instantes, para nao depender do fuso do servidor.
    const diaCandidataUtc = Date.UTC(
      candidata.getFullYear(),
      candidata.getMonth(),
      candidata.getDate(),
    );
    const diaAncoraUtc = Date.UTC(
      dataAncora.getUTCFullYear(),
      dataAncora.getUTCMonth(),
      dataAncora.getUTCDate(),
    );
    const diffDias = Math.round(
      (diaCandidataUtc - diaAncoraUtc) / (1000 * 60 * 60 * 24),
    );
    return diffDias % 2 === 0;
  }

  return true;
};

const jaAdministradoEm = (
  candidata: Date,
  administracoes: { horarioPrevisto: Date }[],
) =>
  administracoes.some((administracao) => {
    const previsto = administracao.horarioPrevisto;
    return (
      previsto.getFullYear() === candidata.getFullYear() &&
      previsto.getMonth() === candidata.getMonth() &&
      previsto.getDate() === candidata.getDate() &&
      previsto.getHours() === candidata.getHours() &&
      previsto.getMinutes() === candidata.getMinutes()
    );
  });

const proximaOcorrencia = (
  horaMinuto: string,
  agora: Date,
  tipoFrequencia: string,
  diasSemana: string | null,
  dataAncora: Date | null,
  administracoesHoje: { horarioPrevisto: Date }[],
): { data: Date; atrasado: boolean } | null => {
  const [hora, minuto] = horaMinuto.split(":").map((parte) => Number(parte));

  for (let offset = 0; offset < 15; offset++) {
    const candidata = new Date(agora);
    candidata.setDate(candidata.getDate() + offset);
    candidata.setHours(hora || 0, minuto || 0, 0, 0);

    if (!diaEhValido(candidata, tipoFrequencia, diasSemana, dataAncora)) {
      continue;
    }

    if (candidata.getTime() > agora.getTime()) {
      return { data: candidata, atrasado: false };
    }

    if (!jaAdministradoEm(candidata, administracoesHoje)) {
      return { data: candidata, atrasado: true };
    }
  }

  return null;
};

const formatarHorario = (valor: unknown) => {
  if (!valor) return null;
  return String(valor).slice(0, 5);
};

const TOLERANCIA_ATRASO_MINUTOS = 30;

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
            texto: "Atrasado",
            cor: "alerta" as const,
          };
        }
      }
      return { descricao: "marcou como tomado", texto: "Tomado", cor: "normal" as const };
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
    const inicioDeHoje = startOfDay(agora);
    const medicamentos = [];
    let proximoMedicamento: Record<string, unknown> | null = null;
    let proximaData: Date | null = null;
    let proximoAtrasado = false;

    for (const medicamento of medicamentosResult.rows) {
      const horariosResult = await getPool().query<{
        horario: string;
        tipo_frequencia: string | null;
        dias_semana: string | null;
      }>(
        `
          select horario, tipo_frequencia, dias_semana
          from horarios_medicamentos
          where medicamento_id = $1
        `,
        [medicamento.id],
      );

      const administracoesHojeResult = await getPool().query<{
        horarioPrevisto: Date;
      }>(
        `
          select horario_previsto as "horarioPrevisto"
          from administracoes_medicamentos
          where medicamento_id = $1
            and horario_previsto >= $2
        `,
        [medicamento.id, inicioDeHoje.toISOString()],
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
          administracoesHojeResult.rows,
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

      const item = {
        id: medicamento.id,
        nome: medicamento.nome,
        dosagem: medicamento.dosagem,
        formato: medicamento.formato,
        quantidadeEstoque:
          medicamento.quantidade_estoque == null
            ? null
            : Number(medicamento.quantidade_estoque),
        unidadeEstoque: medicamento.unidade_estoque,
        alertaEstoqueBaixo:
          medicamento.alerta_estoque_baixo == null
            ? null
            : Number(medicamento.alerta_estoque_baixo),
        proximoHorario,
        proximoAtrasado: atrasado,
        totalHorarios: horariosResult.rows.length,
      };

      medicamentos.push(item);

      const substituiProximo =
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
    const referencia = dataReferencia
      ? new Date(`${dataReferencia}T12:00:00`)
      : new Date();
    const inicio = inicioDoPeriodoHistorico(referencia, periodo);

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
        order by h.criado_em desc
        limit 100
      `,
      [idosoId, inicio.toISOString()],
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
      }>(
        "select id, nome from medicamentos where id = any($1::uuid[])",
        [Array.from(medicamentoIds)],
      );
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
    const administracao = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      "administracoes_medicamentos",
      { ...input, medicamentoId, registradoPorId },
      {
        medicamentoId: "medicamento_id",
        idosoId: "idoso_id",
        horarioPrevisto: "horario_previsto",
        administradoEm: "administrado_em",
        status: "status",
        quantidadeDose: "quantidade_dose",
        registradoPorId: "registrado_por_id",
        observacoes: "observacoes",
      },
    );

    if (input.status === "tomado" && input.quantidadeDose) {
      await getPool().query(
        `
          update medicamentos
          set quantidade_estoque = greatest(coalesce(quantidade_estoque, 0) - $1, 0)
          where id = $2
        `,
        [input.quantidadeDose, medicamentoId],
      );
    }

    await registrarHistorico({
      usuarioId: registradoPorId,
      idosoId: input.idosoId,
      acao: "registrar_administracao",
      tipoEntidade: "administracoes_medicamentos",
      entidadeId: String(administracao.id),
      dadosNovos: administracao,
    });

    return administracao;
  },
};
