import { z } from "zod";

import { isFutureInstant } from "../../common/utils/date-utils.js";

const dataNaoFuturaSchema = z
  .string()
  .datetime("Data deve estar em formato ISO.")
  .refine(
    (value) => !isFutureInstant(value),
    "Não é permitido registrar uma data futura.",
  );

const valorSaturacaoSchema = z
  .number()
  .int("Valor deve ser um número inteiro.")
  .min(0, "Valor mínimo permitido é 0%.")
  .max(100, "Valor máximo permitido é 100%.");

const valorPulsoSchema = z
  .number()
  .int("Valor deve ser um número inteiro.")
  .min(20, "Valor mínimo permitido é 20 bpm.")
  .max(250, "Valor máximo permitido é 250 bpm.");

export const criarOxigenacaoSchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  saturacao: valorSaturacaoSchema,
  pulso: valorPulsoSchema.optional(),
  medidoEm: dataNaoFuturaSchema,
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarOxigenacaoSchema = criarOxigenacaoSchema.partial();

export const resumoOxigenacaoQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  dataReferencia: z.string().date().optional(),
  periodo: z.enum(["dia", "semanal", "mes"]).default("dia"),
});

export const historicoOxigenacaoQuerySchema = resumoOxigenacaoQuerySchema;

export type CriarOxigenacaoInput = z.infer<typeof criarOxigenacaoSchema>;
export type AtualizarOxigenacaoInput = z.infer<
  typeof atualizarOxigenacaoSchema
>;
export type ResumoOxigenacaoQuery = z.infer<typeof resumoOxigenacaoQuerySchema>;
export type HistoricoOxigenacaoQuery = z.infer<
  typeof historicoOxigenacaoQuerySchema
>;
