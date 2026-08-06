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
  criadoPorId?: string | null;
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
  criado_por_id: string | null;
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
  criadoPorId: row.criado_por_id,
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

const quoteIdentifier = (value: string): string =>
  `"${value.replace(/"/g, '""')}"`;

const limparDadosDaFicha = async (idosoId: string) => {
  const pool = getPool();

  await pool.query("delete from historico_alteracoes where idoso_id = $1", [
    idosoId,
  ]);
  await pool.query("update conversas_ia set idoso_id = null where idoso_id = $1", [
    idosoId,
  ]);

  const tabelas = await pool.query<{ table_schema: string; table_name: string }>(
    `
      select c.table_schema, c.table_name
      from information_schema.columns c
      join information_schema.tables t
        on t.table_schema = c.table_schema
       and t.table_name = c.table_name
      where c.column_name = 'idoso_id'
        and c.table_schema = 'public'
        and t.table_type = 'BASE TABLE'
        and c.table_name not in (
          'fichas_idosos',
          'historico_alteracoes',
          'conversas_ia'
        )
      order by c.table_name
    `,
  );

  for (const tabela of tabelas.rows) {
    await pool.query(
      `delete from ${quoteIdentifier(tabela.table_schema)}.${quoteIdentifier(
        tabela.table_name,
      )} where idoso_id = $1`,
      [idosoId],
    );
  }
};

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
          criado_por_id,
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
          criado_por_id,
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
            criado_por_id,
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

    return this.buscarPorId(String(idoso.id));
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

    return this.buscarPorId(idosoId);
  },

  async remover(idosoId: string, usuarioId?: string) {
    const anterior = await getRowById<
      Record<string, unknown> & { criado_por_id?: string }
    >(
      "fichas_idosos",
      idosoId,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso nao encontrado.",
    );

    if (isDatabaseEnabled && usuarioId && anterior.criado_por_id !== usuarioId) {
      const result = await getPool().query<Record<string, unknown>>(
        `
          update membros_ficha
          set status = 'revogado'
          where idoso_id = $1
            and usuario_id = $2
            and status = 'ativo'
          returning *
        `,
        [idosoId, usuarioId],
      );

      if ((result.rowCount ?? 0) === 0) {
        throw new AppError(
          "ACESSO_FICHA_NAO_ENCONTRADO",
          "Acesso a ficha nao encontrado.",
          404,
        );
      }

      await registrarHistorico({
        usuarioId,
        idosoId,
        acao: "sair",
        tipoEntidade: "membros_ficha",
        entidadeId: String(result.rows[0]?.id ?? idosoId),
        dadosAnteriores: { idoso_id: idosoId, usuario_id: usuarioId },
        dadosNovos: result.rows[0],
      });
      return;
    }

    await this.excluirPermanentemente(idosoId, usuarioId);
  },

  async excluirPermanentemente(idosoId: string, usuarioId?: string) {
    const anterior = await getRowById<
      Record<string, unknown> & { criado_por_id?: string }
    >(
      "fichas_idosos",
      idosoId,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso nao encontrado.",
    );

    if (usuarioId && anterior.criado_por_id !== usuarioId) {
      throw new AppError(
        "APENAS_DONO_EXCLUI_FICHA",
        "Apenas o dono da ficha pode exclui-la permanentemente.",
        403,
      );
    }

    if (isDatabaseEnabled) {
      await limparDadosDaFicha(idosoId);
    }

    await deleteRow(
      "fichas_idosos",
      idosoId,
      "IDOSO_NAO_ENCONTRADO",
      "Idoso nao encontrado.",
    );
    await registrarHistorico({
      usuarioId,
      idosoId: null,
      acao: "excluir",
      tipoEntidade: "fichas_idosos",
      entidadeId: idosoId,
      dadosAnteriores: anterior,
    });
  },
};
