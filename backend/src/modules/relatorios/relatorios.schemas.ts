import { z } from "zod";

export const criarRelatorioSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  tipoRelatorio: z.string().min(1, "Tipo é obrigatório."),
  periodoInicio: z.string().date(),
  periodoFim: z.string().date(),
  resumoTexto: z.string().optional(),
  urlArquivo: z.string().url().optional(),
  geradoPorId: z.string().uuid().optional(),
});

export const atualizarRelatorioSchema = criarRelatorioSchema.partial();

export type CriarRelatorioInput = z.infer<typeof criarRelatorioSchema>;
export type AtualizarRelatorioInput = z.infer<typeof atualizarRelatorioSchema>;
