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
  condicoes: string[];
};

const idosos: Idoso[] = [
  {
    id: "idoso-1",
    nome: "Maria Aparecida",
    idade: 78,
    condicoes: ["Diabetes", "Hipertensão"],
  },
];

type IdosoRow = {
  id: string;
  nome: string;
  idade: number | null;
  observacoes_saude: string | null;
  limitacoes: string | null;
};

const mapearIdoso = (row: IdosoRow): Idoso => ({
  id: row.id,
  nome: row.nome,
  idade: Number(row.idade ?? 0),
  condicoes: [row.observacoes_saude, row.limitacoes].filter(
    (item): item is string => Boolean(item),
  ),
});

const isUuid = (value: string): boolean =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );

const fields = {
  nomeCompleto: "nome_completo",
  dataNascimento: "data_nascimento",
  urlFoto: "url_foto",
  sexo: "sexo",
  observacoesSaude: "observacoes_saude",
  limitacoes: "limitacoes",
  alergiasRestricoes: "alergias_restricoes",
  observacoesGerais: "observacoes_gerais",
  criadoPorId: "criado_por_id",
  ativo: "ativo",
} as const;

export const idososService = {
  async listar(): Promise<Idoso[]> {
    if (isDatabaseEnabled) {
      const result = await getPool().query<IdosoRow>(`
        select
          id,
          nome_completo as nome,
          case
            when data_nascimento is null then null
            else extract(year from age(current_date, data_nascimento))::int
          end as idade,
          observacoes_saude,
          limitacoes
        from fichas_idosos
        where ativo = true
        order by nome_completo
      `);

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
            case
              when data_nascimento is null then null
              else extract(year from age(current_date, data_nascimento))::int
            end as idade,
            observacoes_saude,
            limitacoes
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
    const client = await getPool().connect();

    try {
      await client.query("begin");

      const fichaInput: Record<string, unknown> = {
        nomeCompleto: input.nomeCompleto,
        dataNascimento: input.dataNascimento,
        urlFoto: input.urlFoto,
        sexo: input.sexo,
        observacoesSaude: input.observacoesSaude,
        limitacoes: input.limitacoes,
        alergiasRestricoes: input.alergiasRestricoes,
        observacoesGerais: input.observacoesGerais,
        criadoPorId,
        ativo: input.ativo ?? true,
      };
      const entries = Object.entries(fields)
        .map(([key, column]) => ({ column, value: fichaInput[key] }))
        .filter((entry) => entry.value !== undefined);
      const columns = entries.map((entry) => entry.column).join(", ");
      const placeholders = entries
        .map((_, index) => `$${index + 1}`)
        .join(", ");
      const values = entries.map((entry) => entry.value);

      const idosoResult = await client.query<Record<string, unknown>>(
        `insert into fichas_idosos (${columns}) values (${placeholders}) returning *`,
        values,
      );
      const idoso = idosoResult.rows[0];
      const idosoId = String(idoso.id);

      for (const condicao of input.condicoesSaude ?? []) {
        const nome = condicao.trim();
        if (!nome) continue;

        await client.query(
          "insert into condicoes_saude (idoso_id, nome) values ($1, $2)",
          [idosoId, nome],
        );
      }

      const contato = input.contatoEmergencia;
      const contatoNome = contato?.nome?.trim();
      const contatoTelefone = contato?.telefone?.trim();

      if (contatoNome && contatoTelefone) {
        await client.query(
          `
            insert into contatos_emergencia
              (idoso_id, nome, telefone, relacao, principal)
            values ($1, $2, $3, $4, $5)
          `,
          [
            idosoId,
            contatoNome,
            contatoTelefone,
            contato?.relacao?.trim() || null,
            contato?.principal ?? true,
          ],
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
          idosoId,
          criadoPorId,
          "criar",
          "fichas_idosos",
          idosoId,
          null,
          JSON.stringify({
            ...idoso,
            condicoesSaude: input.condicoesSaude,
            contatoEmergencia: contato,
          }),
        ],
      );

      await client.query("commit");

      return idoso;
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }
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
