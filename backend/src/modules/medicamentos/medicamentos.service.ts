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
} from "./medicamentos.schemas.js";

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
