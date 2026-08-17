import { z } from "zod";

const comum = {
  idosoId: z.string().uuid("Idoso inválido."),
  registradoPorId: z.string().uuid().optional(),
  observacoes: z.string().optional(),
};

export const hidratacaoSchema = z.object({
  ...comum,
  quantidadeMl: z.number().positive(),
  registradoEm: z.string().datetime().optional(),
});

export const humorSchema = z.object({
  ...comum,
  humor: z.string().min(1),
  horarioRegi: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/, "Horário inválido."),
  dataHumor: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Data inválida."),
}).superRefine((value, context) => {
  const registradoEm = new Date(`${value.dataHumor}T${value.horarioRegi}:00`);
  if (!Number.isNaN(registradoEm.getTime()) && registradoEm > new Date()) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["horarioRegi"],
      message: "Não é permitido registrar humor em um horário futuro.",
    });
  }
});

export const sonoSchema = z.object({
  ...comum,
  inicioSono: z.string().datetime(),
  fimSono: z.string().datetime().optional(),
  qualidade: z.string().optional(),
  interrupcoes: z.number().int().nonnegative().optional(),
});

export const oxigenacaoSchema = z.object({
  ...comum,
  spo2: z.number().positive(),
  frequenciaCardiaca: z.number().int().positive().optional(),
  registradoEm: z.string().datetime().optional(),
});

export const pressaoSchema = z.object({
  ...comum,
  sistolica: z.number().int().positive(),
  diastolica: z.number().int().positive(),
  frequenciaCardiaca: z.number().int().positive().optional(),
  medidoEm: z.string().datetime(),
});

export type HidratacaoInput = z.infer<typeof hidratacaoSchema>;
export type HumorInput = z.infer<typeof humorSchema>;
export type SonoInput = z.infer<typeof sonoSchema>;
export type OxigenacaoInput = z.infer<typeof oxigenacaoSchema>;
export type PressaoInput = z.infer<typeof pressaoSchema>;
