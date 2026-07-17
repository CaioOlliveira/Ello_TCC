import { z } from "zod";

const valorGlicemiaSchema = z
  .number()
  .int("Valor deve ser um numero inteiro.")
  .refine((value) => value > 0, "Valor deve ser positivo.")
  .refine(
    (value) => value <= 0 || value >= 20,
    "Valor minimo permitido e 20 mg/dL.",
  )
  .refine((value) => value <= 600, "Valor maximo permitido e 600 mg/dL.");

export const criarGlicemiaSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
  valor: valorGlicemiaSchema,
  contexto: z.string().min(1, "Contexto e obrigatorio."),
  medidoEm: z.string().datetime("Data deve estar em formato ISO."),
  observacoes: z.string().optional(),
  sintomas: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarGlicemiaSchema = criarGlicemiaSchema.partial();

export const resumoGlicemiaQuerySchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
  dataReferencia: z.string().date().optional(),
  periodo: z.enum(["dia", "semanal", "mes"]).default("dia"),
});

export const historicoGlicemiaQuerySchema = resumoGlicemiaQuerySchema;

export const criarInsulinaSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
  glicemiaId: z.string().uuid().optional(),
  nomeInsulina: z.string().optional(),
  tipoInsulina: z.string().min(1, "Tipo de insulina e obrigatorio."),
  doseUnidades: z
    .number()
    .positive("Dose deve ser positiva.")
    .max(200, "Dose maxima permitida e 200 unidades."),
  aplicadoEm: z.string().datetime("Data deve estar em formato ISO."),
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
