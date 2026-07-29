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
  pesoKg?: number | null;
  tipoSanguineo?: string | null;
  dataNascimento?: string | null;
  sexo?: string | null;
  limitacoes?: string | null;
  observacoesGerais?: string | null;
  alergiasRestricoes?: string | null;
  contatoEmergenciaNome?: string | null;
  contatoEmergenciaTelefone?: string | null;
  contatoEmergenciaParentesco?: string | null;
  condicoes: string[];
  monitoramentos: string[];
};

const idosos: Idoso[] = [
  {
    id: "idoso-1",
    nome: "Maria Aparecida",
    idade: 78,
    sexo: "Feminino",
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
  peso_kg: string | number | null;
  tipo_sanguineo: string | null;
  data_nascimento: string | null;
  sexo: string | null;
  observacoes_saude: string | null;
  observacoes_gerais: string | null;
  limitacoes: string | null;
  alergias_restricoes: string | null;
  contato_emergencia_nome: string | null;
  contato_emergencia_telefone: string | null;
  contato_emergencia_parentesco: string | null;
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
  pesoKg: row.peso_kg == null ? null : Number(row.peso_kg),
  tipoSanguineo: row.tipo_sanguineo,
  dataNascimento: row.data_nascimento,
  sexo: row.sexo,
  limitacoes: row.limitacoes,
  observacoesGerais: row.observacoes_gerais,
  alergiasRestricoes: row.alergias_restricoes,
  contatoEmergenciaNome: row.contato_emergencia_nome,
  contatoEmergenciaTelefone: row.contato_emergencia_telefone,
  contatoEmergenciaParentesco: row.contato_emergencia_parentesco,
  condicoes:
    typeof row.observacoes_saude === "string" && row.observacoes_saude.trim()
      ? row.observacoes_saude
          .split(",")
          .map((item) => item.trim())
          .filter(Boolean)
      : [],
  monitoramentos: normalizarMonitoramentos(row.monitoramentos),
});

const isUuid = (value: string): boolean =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );

const prepararInput = <T extends AtualizarIdosoInput | CriarIdosoInput>(
  input: T,
): Record<string, unknown> => ({
  ...input,
  observacoesSaude: input.observacoesSaude ?? input.condicoesSaude?.join(", "),
  limitacoes: input.limitacoes,
  alergiasRestricoes: input.alergiasRestricoes,
});

const salvarObservacaoGeral = async (
  idosoId: string,
  conteudo: string | undefined,
  usuarioId: string | undefined,
) => {
  const texto = conteudo?.trim();
  if (!texto || !usuarioId) return;

  await getPool().query(
    `
      insert into observacoes_gerais (
        idoso_id,
        tipo_observacao,
        conteudo,
        registrado_por_id
      )
      values ($1, 'ficha_idoso', $2, $3)
    `,
    [idosoId, texto, usuarioId],
  );
};

const fields = {
  nomeCompleto: "nome_completo",
  dataNascimento: "data_nascimento",
  urlFoto: "url_foto",
  pesoKg: "peso_kg",
  sexo: "sexo",
  tipoSanguineo: "tipo_sanguineo",
  observacoesSaude: "observacoes_saude",
  limitacoes: "limitacoes",
  alergiasRestricoes: "alergias_restricoes",
  contatoEmergenciaNome: "contato_emergencia_nome",
  contatoEmergenciaTelefone: "contato_emergencia_telefone",
  contatoEmergenciaParentesco: "contato_emergencia_parentesco",
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
          peso_kg,
          tipo_sanguineo,
          data_nascimento,
          sexo,
          case
            when data_nascimento is null then null
            else extract(year from age(current_date, data_nascimento))::int
          end as idade,
          observacoes_saude,
          (
            select conteudo
            from observacoes_gerais og
            where og.idoso_id = fichas_idosos.id
            order by registrado_em desc
            limit 1
          ) as observacoes_gerais,
          limitacoes,
          alergias_restricoes,
          contato_emergencia_nome,
          contato_emergencia_telefone,
          contato_emergencia_parentesco,
          monitoramentos
        from fichas_idosos
        where ativo = true
          and (
            $1::uuid is null
            or criado_por_id = $1::uuid
            or exists (
              select 1
              from membros_ficha mf
              where mf.idoso_id = fichas_idosos.id
                and mf.usuario_id = $1::uuid
                and mf.status = 'ativo'
            )
          )
        order by nome_completo
      `,
        [filtros.usuarioId ?? null],
      );

      return result.rows.map(mapearIdoso);
    }

    return idosos;
  },

  async listarAdministrados(usuarioId: string): Promise<Idoso[]> {
    if (!isDatabaseEnabled) return idosos;

    const result = await getPool().query<IdosoRow>(
      `
        select
          id,
          nome_completo as nome,
          url_foto,
          peso_kg,
          tipo_sanguineo,
          data_nascimento,
          sexo,
          case
            when data_nascimento is null then null
            else extract(year from age(current_date, data_nascimento))::int
          end as idade,
          observacoes_saude,
          (
            select conteudo
            from observacoes_gerais og
            where og.idoso_id = fichas_idosos.id
            order by registrado_em desc
            limit 1
          ) as observacoes_gerais,
          limitacoes,
          alergias_restricoes,
          contato_emergencia_nome,
          contato_emergencia_telefone,
          contato_emergencia_parentesco,
          monitoramentos
        from fichas_idosos
        where ativo = true
          and (
            criado_por_id = $1::uuid
            or exists (
              select 1
              from membros_ficha mf
              where mf.idoso_id = fichas_idosos.id
                and mf.usuario_id = $1::uuid
                and mf.status = 'ativo'
                and mf.e_administrador = true
            )
          )
        order by nome_completo
      `,
      [usuarioId],
    );

    return result.rows.map(mapearIdoso);
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
            peso_kg,
            tipo_sanguineo,
            data_nascimento,
            sexo,
            case
              when data_nascimento is null then null
              else extract(year from age(current_date, data_nascimento))::int
            end as idade,
            observacoes_saude,
            (
              select conteudo
              from observacoes_gerais og
              where og.idoso_id = fichas_idosos.id
              order by registrado_em desc
              limit 1
            ) as observacoes_gerais,
            limitacoes,
            alergias_restricoes,
            contato_emergencia_nome,
            contato_emergencia_telefone,
            contato_emergencia_parentesco,
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
        ...prepararInput(input),
        criadoPorId,
        ativo: input.ativo ?? true,
      },
      fields,
    );

    await salvarObservacaoGeral(
      String(idoso.id),
      input.observacoesGerais,
      criadoPorId,
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
      prepararInput(input),
      fields,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso não encontrado.",
    );

    await salvarObservacaoGeral(
      idosoId,
      input.observacoesGerais,
      input.criadoPorId,
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
