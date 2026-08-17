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
  AtualizarEquipamentoInput,
  CriarEquipamentoInput,
  CriarManutencaoInput,
} from "./equipamentos.schemas.js";

const table = "equipamentos";
const notFound = [
  "EQUIPAMENTO_NAO_ENCONTRADO",
  "Equipamento não encontrado.",
] as const;

const fields = {
  idosoId: "idoso_id",
  nome: "nome",
  tipo: "tipo",
  marca: "marca",
  modelo: "modelo",
  numeroSerie: "numero_serie",
  dataAquisicao: "data_aquisicao",
  validade: "validade",
  ultimaManutencaoEm: "ultima_manutencao_em",
  localGuardado: "local_guardado",
  responsavelId: "responsavel_id",
  criadoPorId: "criado_por_id",
  urlManual: "url_manual",
  urlFoto: "url_foto",
  frequenciaManutencaoDias: "frequencia_manutencao_dias",
  proximaManutencaoEm: "proxima_manutencao_em",
  status: "status",
  observacoesSeguranca: "observacoes_seguranca",
} as const;

export const equipamentosService = {
  async listar(limit: number, offset: number, idosoId?: string) {
    return listRows<Record<string, unknown>>(table, {
      limit,
      offset,
      where: idosoId ? "idoso_id = $1" : undefined,
      params: idosoId ? [idosoId] : undefined,
      orderBy: "nome asc",
    });
  },

  async listarHistorico(limit: number, offset: number, idosoId?: string) {
    const params: unknown[] = ["equipamentos", "manutencoes_equipamentos"];
    const filters = ["h.tipo_entidade in ($1, $2)"];

    if (idosoId) {
      params.push(idosoId);
      filters.push(`h.idoso_id = $${params.length}`);
    }

    const where = filters.join(" and ");
    const countResult = await getPool().query<{ total: string }>(
      `select count(*) as total from historico_alteracoes h where ${where}`,
      params,
    );

    const result = await getPool().query<Record<string, unknown>>(
      `
        select
          h.*,
          u.nome as usuario_nome,
          coalesce(
            e.nome,
            h.dados_novos ->> 'nome',
            h.dados_anteriores ->> 'nome'
          ) as equipamento_nome
        from historico_alteracoes h
        left join usuarios u on u.id = h.usuario_id
        left join manutencoes_equipamentos me
          on h.tipo_entidade = 'manutencoes_equipamentos'
         and me.id::text = h.entidade_id::text
        left join equipamentos e
          on e.id = coalesce(me.equipamento_id, h.entidade_id::uuid)
        where ${where}
        order by h.criado_em desc
        limit $${params.length + 1} offset $${params.length + 2}
      `,
      [...params, limit, offset],
    );

    return {
      dados: result.rows,
      total: Number(countResult.rows[0]?.total ?? 0),
    };
  },

  async buscarPorId(id: string) {
    return getRowById<Record<string, unknown>>(table, id, ...notFound);
  },

  async criar(input: CriarEquipamentoInput) {
    const criadoPorId = await resolverUsuarioRegistroId(input.criadoPorId);
    const equipamento = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      table,
      {
        ...input,
        criadoPorId,
        responsavelId: input.responsavelId ?? criadoPorId,
        status: input.status ?? "Em uso",
      },
      fields,
    );
    await registrarHistorico({
      usuarioId: criadoPorId,
      idosoId: input.idosoId,
      acao: "criar",
      tipoEntidade: table,
      entidadeId: String(equipamento.id),
      dadosNovos: equipamento,
    });
    return equipamento;
  },

  async atualizar(id: string, input: AtualizarEquipamentoInput) {
    const anterior = await this.buscarPorId(id);
    const { registradoPorId, ...dadosEquipamento } = input;
    const atualizado = await updateRow<
      Omit<AtualizarEquipamentoInput, "registradoPorId">,
      Record<string, unknown>
    >(table, id, dadosEquipamento, fields, ...notFound);
    await registrarHistorico({
      usuarioId: await resolverUsuarioRegistroId(
        registradoPorId ?? input.criadoPorId,
      ),
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
    await getPool().query(
      `delete from manutencoes_equipamentos where equipamento_id = $1`,
      [id],
    );
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

  async listarManutencoes(equipamentoId: string) {
    await this.buscarPorId(equipamentoId);
    const result = await getPool().query<Record<string, unknown>>(
      `select * from manutencoes_equipamentos
       where equipamento_id = $1
       order by data_manutencao desc nulls last, criado_em desc nulls last`,
      [equipamentoId],
    );

    return result.rows;
  },

  async registrarManutencao(
    equipamentoId: string,
    input: CriarManutencaoInput,
  ) {
    const equipamento = await this.buscarPorId(equipamentoId);
    const registradoPorId = await resolverUsuarioRegistroId(
      input.registradoPorId,
    );
    const manutencao = await insertRow<
      Record<string, unknown>,
      Record<string, unknown>
    >(
      "manutencoes_equipamentos",
      { ...input, equipamentoId, registradoPorId },
      {
        equipamentoId: "equipamento_id",
        dataManutencao: "data_manutencao",
        tipoManutencao: "tipo_manutencao",
        descricaoServico: "descricao_servico",
        problemaRelatado: "problema_relatado",
        pecasTrocadas: "pecas_trocadas",
        profissionalEmpresa: "profissional_empresa",
        proximaManutencaoEm: "proxima_manutencao_em",
        custo: "custo",
        observacoes: "observacoes",
        registradoPorId: "registrado_por_id",
      },
    );

    await updateRow<Record<string, unknown>, Record<string, unknown>>(
      table,
      equipamentoId,
      {
        ultimaManutencaoEm: input.dataManutencao,
        proximaManutencaoEm: input.proximaManutencaoEm,
        status: "Em uso",
      },
      fields,
      ...notFound,
    );

    await registrarHistorico({
      usuarioId: registradoPorId,
      idosoId: String(equipamento.idoso_id ?? ""),
      acao: "registrar_manutencao",
      tipoEntidade: "manutencoes_equipamentos",
      entidadeId: String(manutencao.id),
      dadosNovos: manutencao,
    });

    return manutencao;
  },
};
