import { z } from "zod";

export const criarMedicamentoSchema = z.object({
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
});

export const atualizarMedicamentoSchema = criarMedicamentoSchema.partial();

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

export const substituirHorariosMedicamentoSchema = z.object({
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
export type SubstituirHorariosMedicamentoInput = z.infer<
  typeof substituirHorariosMedicamentoSchema
>;
export type ResumoMedicamentosQuery = z.infer<
  typeof resumoMedicamentosQuerySchema
>;
export type HistoricoMedicamentosQuery = z.infer<
  typeof historicoMedicamentosQuerySchema
>;
