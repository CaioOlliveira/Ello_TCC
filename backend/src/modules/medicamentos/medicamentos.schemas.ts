import { z } from "zod";

const medicamentoSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  nome: z.string().min(1, "Nome é obrigatório."),
  dosagem: z.string().optional(),
  formato: z.string().optional(),
  instrucoes: z.string().optional(),
  dataInicio: z.string().date().optional(),
  dataFim: z.string().date().optional(),
  quantidadeEstoque: z.number().nonnegative().optional(),
  unidadeEstoque: z.string().optional(),
  alertaEstoqueBaixo: z.number().nonnegative().optional(),
  ativo: z.boolean().optional(),
  registradoPorId: z.string().uuid().optional(),
});

const validarPeriodoMedicamento = (
  dados: { dataInicio?: string; dataFim?: string },
  context: z.RefinementCtx,
) => {
  if (
    dados.dataInicio &&
    dados.dataFim &&
    dados.dataFim < dados.dataInicio
  ) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["dataFim"],
      message: "A data de término não pode ser anterior à data de início.",
    });
  }
};

export const criarMedicamentoSchema = medicamentoSchema.superRefine(
  validarPeriodoMedicamento,
);

export const atualizarMedicamentoSchema = medicamentoSchema
  .partial()
  .superRefine(validarPeriodoMedicamento);

export const criarHorarioMedicamentoSchema = z.object({
  tipoFrequencia: z.string().min(1),
  horario: z.string().min(1),
  quantidadeDose: z.number().positive().optional(),
  unidadeDose: z.string().optional(),
  diasSemana: z.string().optional(),
});

export const registrarAdministracaoSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  horarioPrevisto: z.string().datetime(),
  administradoEm: z.string().datetime().optional(),
  status: z.string().min(1),
  quantidadeDose: z.number().positive().optional(),
  registradoPorId: z.string().uuid().optional(),
  observacoes: z.string().optional(),
});

export const cancelarAdministracaoSchema = z.object({
  idosoId: z.string().uuid("Idoso inv\u00e1lido."),
});

export const listarSolicitacoesCancelamentoSchema = z.object({
  idosoId: z.string().uuid("Idoso inv\u00e1lido."),
});

export const responderSolicitacaoCancelamentoSchema = z.object({
  aprovar: z.boolean(),
});

export const administracaoParamSchema = z.object({
  administracaoId: z.string().uuid("Administra\u00e7\u00e3o inv\u00e1lida."),
});

export const substituirHorariosMedicamentoSchema = z.object({
  frequenciaTipo: z.enum(["diaria", "semanal", "alternado"]).default("diaria"),
  diasSemana: z.array(z.string().min(1)).optional(),
  horarios: z.array(
    z.object({
      horario: z.string().min(1),
      quantidadeDose: z.number().positive().optional(),
      unidadeDose: z.string().optional(),
    }),
  ),
  registradoPorId: z.string().uuid().optional(),
});

export const resumoMedicamentosQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
});

export const historicoMedicamentosQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  dataReferencia: z.string().date().optional(),
  periodo: z.enum(["dia", "semanal", "mes"]).default("dia"),
});

export type CriarMedicamentoInput = z.infer<typeof criarMedicamentoSchema>;
export type AtualizarMedicamentoInput = z.infer<
  typeof atualizarMedicamentoSchema
>;
export type CriarHorarioMedicamentoInput = z.infer<
  typeof criarHorarioMedicamentoSchema
>;
export type RegistrarAdministracaoInput = z.infer<
  typeof registrarAdministracaoSchema
>;
export type CancelarAdministracaoInput = z.infer<
  typeof cancelarAdministracaoSchema
>;
export type ResponderSolicitacaoCancelamentoInput = z.infer<
  typeof responderSolicitacaoCancelamentoSchema
>;
export type SubstituirHorariosMedicamentoInput = z.infer<
  typeof substituirHorariosMedicamentoSchema
>;
export type ResumoMedicamentosQuery = z.infer<
  typeof resumoMedicamentosQuerySchema
>;
export type HistoricoMedicamentosQuery = z.infer<
  typeof historicoMedicamentosQuerySchema
>;
