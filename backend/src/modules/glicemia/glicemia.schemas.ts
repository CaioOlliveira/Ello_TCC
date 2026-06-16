import { z } from "zod";

export const criarGlicemiaSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
  valor: z.number().positive("Valor deve ser positivo."),
  contexto: z.string().min(1, "Contexto e obrigatorio."),
  medidoEm: z.string().datetime("Data deve estar em formato ISO."),
  observacoes: z.string().optional(),
  sintomas: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarGlicemiaSchema = criarGlicemiaSchema.partial();

export type CriarGlicemiaInput = z.infer<typeof criarGlicemiaSchema>;
export type AtualizarGlicemiaInput = z.infer<typeof atualizarGlicemiaSchema>;
