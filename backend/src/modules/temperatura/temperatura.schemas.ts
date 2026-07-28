import { z } from "zod";

const valorTemperaturaSchema = z
  .number()
  .min(25, "Valor minimo permitido e 25°C.")
  .max(45, "Valor maximo permitido e 45°C.");

export const criarTemperaturaSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
  temperatura: valorTemperaturaSchema,
  medidoEm: z.string().datetime("Data deve estar em formato ISO."),
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarTemperaturaSchema = criarTemperaturaSchema.partial();

export const resumoTemperaturaQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
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
