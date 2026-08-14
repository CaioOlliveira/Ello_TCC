import { z } from "zod";

const valorTemperaturaSchema = z
  .number()
  .min(25, "Valor mínimo permitido é 25°C.")
  .max(45, "Valor máximo permitido é 45°C.");

export const criarTemperaturaSchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  temperatura: valorTemperaturaSchema,
  medidoEm: z.string().datetime("Data deve estar em formato ISO."),
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarTemperaturaSchema = criarTemperaturaSchema.partial();

export const resumoTemperaturaQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  dataReferencia: z.string().date().optional(),
  periodo: z.enum(["dia", "semanal", "mes"]).default("dia"),
});

export const historicoTemperaturaQuerySchema = resumoTemperaturaQuerySchema;

export type CriarTemperaturaInput = z.infer<typeof criarTemperaturaSchema>;
export type AtualizarTemperaturaInput = z.infer<
  typeof atualizarTemperaturaSchema
>;
export type ResumoTemperaturaQuery = z.infer<
  typeof resumoTemperaturaQuerySchema
>;
export type HistoricoTemperaturaQuery = z.infer<
  typeof historicoTemperaturaQuerySchema
>;
