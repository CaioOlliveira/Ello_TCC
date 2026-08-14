import { z } from "zod";

import { isFutureInstant } from "../../common/utils/date-utils.js";

const dataNaoFuturaSchema = z
  .string()
  .datetime("Data deve estar em formato ISO.")
  .refine(
    (value) => !isFutureInstant(value),
    "Não é permitido registrar uma data futura.",
  );

const valorGlicemiaSchema = z
  .number()
  .int("Valor deve ser um número inteiro.")
  .refine((value) => value > 0, "Valor deve ser positivo.")
  .refine(
    (value) => value <= 0 || value >= 20,
    "Valor mínimo permitido é 20 mg/dL.",
  )
  .refine((value) => value <= 600, "Valor máximo permitido é 600 mg/dL.");

export const criarGlicemiaSchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  valor: valorGlicemiaSchema,
  contexto: z.string().min(1, "Contexto é obrigatório."),
  medidoEm: dataNaoFuturaSchema,
  observacoes: z.string().optional(),
  sintomas: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarGlicemiaSchema = criarGlicemiaSchema.partial();

export const resumoGlicemiaQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  dataReferencia: z.string().date().optional(),
  periodo: z.enum(["dia", "semanal", "mes"]).default("dia"),
});

export const historicoGlicemiaQuerySchema = resumoGlicemiaQuerySchema;

export const criarInsulinaSchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
  glicemiaId: z.string().uuid().optional(),
  nomeInsulina: z.string().optional(),
  tipoInsulina: z.string().min(1, "Tipo de insulina é obrigatório."),
  doseUnidades: z
    .number()
    .positive("Dose deve ser positiva.")
    .max(200, "Dose máxima permitida é 200 unidades."),
  aplicadoEm: dataNaoFuturaSchema,
  localAplicacao: z.string().optional(),
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export type CriarGlicemiaInput = z.infer<typeof criarGlicemiaSchema>;
export type AtualizarGlicemiaInput = z.infer<typeof atualizarGlicemiaSchema>;
export type ResumoGlicemiaQuery = z.infer<typeof resumoGlicemiaQuerySchema>;
export type HistoricoGlicemiaQuery = z.infer<
  typeof historicoGlicemiaQuerySchema
>;
export type CriarInsulinaInput = z.infer<typeof criarInsulinaSchema>;
