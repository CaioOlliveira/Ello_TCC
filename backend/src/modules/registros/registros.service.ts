import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import { insertRow, listRows } from "../../database/simple-crud.js";
import { notificacoesService } from "../notificacoes/notificacoes.service.js";

type RegistroConfig = {
  table: string;
  tipoEntidade: string;
  orderBy: string;
  fields: Record<string, string>;
};

const configs = {
  hidratacao: {
    table: "registros_hidratacao",
    tipoEntidade: "registros_hidratacao",
    orderBy: "registrado_em desc",
    fields: {
      idosoId: "idoso_id",
      quantidadeMl: "quantidade_ml",
      registradoEm: "registrado_em",
      registradoPorId: "registrado_por_id",
      observacoes: "observacoes",
    },
  },
  humor: {
    table: "registros_humor",
    tipoEntidade: "registros_humor",
    orderBy: "data_humor desc, horario_regi desc",
    fields: {
      idosoId: "idoso_id",
      humor: "humor",
      horarioRegi: "horario_regi",
      dataHumor: "data_humor",
      observacoes: "observacoes",
      registradoPorId: "registrado_por_id",
    },
  },
  sono: {
    table: "registros_sono",
    tipoEntidade: "registros_sono",
    orderBy: "inicio_sono desc",
    fields: {
      idosoId: "idoso_id",
      inicioSono: "inicio_sono",
      fimSono: "fim_sono",
      qualidade: "qualidade",
      interrupcoes: "interrupcoes",
      observacoes: "observacoes",
      registradoPorId: "registrado_por_id",
    },
  },
  oxigenacao: {
    table: "registros_oxigenacao",
    tipoEntidade: "registros_oxigenacao",
    orderBy: "registrado_em desc",
    fields: {
      idosoId: "idoso_id",
      spo2: "spo2",
      frequenciaCardiaca: "frequencia_cardiaca",
      registradoEm: "registrado_em",
      observacoes: "observacoes",
      registradoPorId: "registrado_por_id",
    },
  },
  pressao: {
    table: "registros_pressao_arterial",
    tipoEntidade: "registros_pressao_arterial",
    orderBy: "medido_em desc",
    fields: {
      idosoId: "idoso_id",
      sistolica: "sistolica",
      diastolica: "diastolica",
      frequenciaCardiaca: "frequencia_cardiaca",
      medidoEm: "medido_em",
      observacoes: "observacoes",
      registradoPorId: "registrado_por_id",
    },
  },
} satisfies Record<string, RegistroConfig>;

type RegistroTipo = keyof typeof configs;

export const registrosService = {
  async listar(
    tipo: RegistroTipo,
    limit: number,
    offset: number,
    idosoId?: string,
  ) {
    const config = configs[tipo];
    return listRows<Record<string, unknown>>(config.table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: config.orderBy,
    });
  },

  async criar(tipo: RegistroTipo, input: Record<string, unknown>) {
    const config = configs[tipo];
    const registradoPorId = await resolverUsuarioRegistroId(
      typeof input.registradoPorId === "string"
        ? input.registradoPorId
        : undefined,
    );
    const registro = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(config.table, { ...input, registradoPorId }, config.fields);

    await registrarHistorico({
      usuarioId: registradoPorId,
      idosoId: String(input.idosoId),
      acao: "criar",
      tipoEntidade: config.tipoEntidade,
      entidadeId: String(registro.id),
      dadosNovos: registro,
    });

    if (tipo === "humor") {
      await notificarFamiliaSobreHumor({
        idosoId: String(input.idosoId),
        registroId: String(registro.id),
        humor: String(input.humor ?? ""),
      });
    }

    return registro;
  },
};

async function notificarFamiliaSobreHumor({
  idosoId,
  registroId,
  humor,
}: {
  idosoId: string;
  registroId: string;
  humor: string;
}) {
  if (!isDatabaseEnabled) return;

  const result = await getPool().query<{ usuario_id: string }>(
    `
      select distinct usuario_id
      from (
        select usuario_id
        from membros_ficha
        where idoso_id = $1
          and lower(coalesce(status, 'ativo')) = 'ativo'
        union
        select criado_por_id as usuario_id
        from fichas_idosos
        where id = $1
      ) usuarios
      where usuario_id is not null
    `,
    [idosoId],
  );

  await Promise.all(
    result.rows.map((row) =>
      notificacoesService.criar({
        idosoId,
        usuarioId: row.usuario_id,
        titulo: "Novo registro de humor",
        mensagem: `Um novo humor foi registrado: ${humor}.`,
        tipoNotificacao: "humor",
        tipoEntidadeRelacionada: "registros_humor",
        entidadeRelacionadaId: registroId,
      }),
    ),
  );
}
