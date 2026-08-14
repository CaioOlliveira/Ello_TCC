import { z } from "zod";

import { isFutureInstant } from "../../common/utils/date-utils.js";

const dataNaoFuturaSchema = z
  .string()
  .datetime("Data deve estar em formato ISO.")
  .refine(
    (value) => !isFutureInstant(value),
    "Não é permitido registrar uma data futura.",
  );

const valorSistolicaSchema = z
  .number()
  .int("Valor deve ser um número inteiro.")
  .min(40, "Valor mínimo permitido é 40 mmHg.")
  .max(300, "Valor máximo permitido é 300 mmHg.");

const valorDiastolicaSchema = z
  .number()
  .int("Valor deve ser um número inteiro.")
  .min(20, "Valor mínimo permitido é 20 mmHg.")
  .max(200, "Valor máximo permitido é 200 mmHg.");

export const criarPressaoSchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  sistolica: valorSistolicaSchema,
  diastolica: valorDiastolicaSchema,
  batimentos: z.number().int().min(20).max(250).optional(),
  medidoEm: dataNaoFuturaSchema,
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarPressaoSchema = criarPressaoSchema.partial();

export const resumoPressaoQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  dataReferencia: z.string().date().optional(),
  periodo: z.enum(["dia", "semanal", "mes"]).default("dia"),
});

export const historicoPressaoQuerySchema = resumoPressaoQuerySchema;

export type CriarPressaoInput = z.infer<typeof criarPressaoSchema>;
export type AtualizarPressaoInput = z.infer<typeof atualizarPressaoSchema>;
export type ResumoPressaoQuery = z.infer<typeof resumoPressaoQuerySchema>;
export type HistoricoPressaoQuery = z.infer<typeof historicoPressaoQuerySchema>;
