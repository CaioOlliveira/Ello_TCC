import { AppError } from "../../common/errors/app-error.js";
import { registrarHistorico } from "../../database/audit.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import { resolverUsuarioRegistroId } from "../../database/usuario-demo.js";
import {
  deleteRow,
  getRowById,
  insertRow,
  updateRow,
} from "../../database/simple-crud.js";
import type { AtualizarIdosoInput, CriarIdosoInput } from "./idosos.schemas.js";

export type Idoso = {
  id: string;
  nome: string;
  idade: number;
  urlFoto?: string | null;
  condicoes: string[];
  monitoramentos: string[];
};

const idosos: Idoso[] = [
  {
    id: "idoso-1",
    nome: "Maria Aparecida",
    idade: 78,
    monitoramentos: [
      "Medicacoes",
      "Humor",
      "Agenda",
      "Alimentacao",
      "Equipamentos",
      "Insumos",
      "Glicemia",
    ],
    condicoes: ["Diabetes", "Hipertensão"],
  },
];

type IdosoRow = {
  id: string;
  nome: string;
  idade: number | null;
  url_foto: string | null;
  observacoes_saude: string | null;
  limitacoes: string | null;
  monitoramentos: unknown;
};

const normalizarMonitoramentos = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value.map((item) => String(item)).filter(Boolean);
  }

  if (typeof value === "string" && value.trim()) {
    return value
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
  }

  return [];
};

const mapearIdoso = (row: IdosoRow): Idoso => ({
  id: row.id,
  nome: row.nome,
  idade: Number(row.idade ?? 0),
  urlFoto: row.url_foto,
  condicoes: [row.observacoes_saude, row.limitacoes].filter(
    (item): item is string => Boolean(item),
  ),
  monitoramentos: normalizarMonitoramentos(row.monitoramentos),
});

const isUuid = (value: string): boolean =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );

const fields = {
  nomeCompleto: "nome_completo",
  dataNascimento: "data_nascimento",
  urlFoto: "url_foto",
  observacoesSaude: "observacoes_saude",
  limitacoes: "limitacoes",
  observacoesEmergencia: "observacoes_emergencia",
  monitoramentos: "monitoramentos",
  criadoPorId: "criado_por_id",
  ativo: "ativo",
} as const;

export const idososService = {
  async listar(filtros: { usuarioId?: string } = {}): Promise<Idoso[]> {
    if (isDatabaseEnabled) {
      const result = await getPool().query<IdosoRow>(
        `
        select
          id,
          nome_completo as nome,
          url_foto,
          case
            when data_nascimento is null then null
            else extract(year from age(current_date, data_nascimento))::int
          end as idade,
          observacoes_saude,
          limitacoes,
          monitoramentos
        from fichas_idosos
        where ativo = true
          and ($1::uuid is null or criado_por_id = $1::uuid)
        order by nome_completo
      `,
        [filtros.usuarioId ?? null],
      );

      return result.rows.map(mapearIdoso);
    }

    return idosos;
  },

  async buscarPorId(idosoId: string): Promise<Idoso> {
    if (isDatabaseEnabled) {
      if (!isUuid(idosoId)) {
        throw new AppError(
          "IDOSO_NAO_ENCONTRADO",
          "Idoso não encontrado.",
          404,
        );
      }

      const result = await getPool().query<IdosoRow>(
        `
          select
            id,
            nome_completo as nome,
            url_foto,
            case
              when data_nascimento is null then null
              else extract(year from age(current_date, data_nascimento))::int
            end as idade,
            observacoes_saude,
            limitacoes,
            monitoramentos
          from fichas_idosos
          where id = $1 and ativo = true
          limit 1
        `,
        [idosoId],
      );

      const idosoBanco = result.rows[0];

      if (!idosoBanco) {
        throw new AppError(
          "IDOSO_NAO_ENCONTRADO",
          "Idoso não encontrado.",
          404,
        );
      }

      return mapearIdoso(idosoBanco);
    }

    const idoso = idosos.find((item) => item.id === idosoId);

    if (!idoso) {
      throw new AppError("IDOSO_NAO_ENCONTRADO", "Idoso não encontrado.", 404);
    }

    return idoso;
  },

  async criar(input: CriarIdosoInput) {
    const criadoPorId = await resolverUsuarioRegistroId(input.criadoPorId);
    const idoso = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      "fichas_idosos",
      {
        ...input,
        criadoPorId,
        ativo: input.ativo ?? true,
      },
      fields,
    );

    await registrarHistorico({
      usuarioId: criadoPorId,
      idosoId: String(idoso.id),
      acao: "criar",
      tipoEntidade: "fichas_idosos",
      entidadeId: String(idoso.id),
      dadosNovos: idoso,
    });

    return idoso;
  },

  async atualizar(idosoId: string, input: AtualizarIdosoInput) {
    const anterior = await getRowById<Record<string, unknown>>(
      "fichas_idosos",
      idosoId,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso não encontrado.",
    );
    const atualizado = await updateRow<
      AtualizarIdosoInput,
      Record<string, unknown>
    >(
      "fichas_idosos",
      idosoId,
      input,
      fields,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso não encontrado.",
    );

    await registrarHistorico({
      usuarioId: input.criadoPorId,
      idosoId,
      acao: "atualizar",
      tipoEntidade: "fichas_idosos",
      entidadeId: idosoId,
      dadosAnteriores: anterior,
      dadosNovos: atualizado,
    });

    return atualizado;
  },

  async remover(idosoId: string, usuarioId?: string) {
    const anterior = await getRowById<Record<string, unknown>>(
      "fichas_idosos",
      idosoId,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso não encontrado.",
    );

    const atualizado = await updateRow<
      { ativo: boolean },
      Record<string, unknown>
    >(
      "fichas_idosos",
      idosoId,
      { ativo: false },
      { ativo: "ativo" },
      "IDOSO_NAO_ENCONTRADO",
      "Idoso não encontrado.",
    );

    await registrarHistorico({
      usuarioId,
      idosoId,
      acao: "desativar",
      tipoEntidade: "fichas_idosos",
      entidadeId: idosoId,
      dadosAnteriores: anterior,
      dadosNovos: atualizado,
    });
  },

  async excluirPermanentemente(idosoId: string, usuarioId?: string) {
    const anterior = await getRowById<Record<string, unknown>>(
      "fichas_idosos",
      idosoId,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso não encontrado.",
    );
    await deleteRow(
      "fichas_idosos",
      idosoId,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso não encontrado.",
    );
    await registrarHistorico({
      usuarioId,
      idosoId,
      acao: "excluir",
      tipoEntidade: "fichas_idosos",
      entidadeId: idosoId,
      dadosAnteriores: anterior,
    });
  },
};
