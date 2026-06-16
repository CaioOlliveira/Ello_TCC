import { z } from "zod";

export const criarRefeicaoSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
  tipoRefeicao: z.string().min(1, "Tipo de refeicao e obrigatorio."),
  alimentos: z.array(z.string().min(1)).min(1, "Informe ao menos um alimento."),
  aceitacao: z.string().min(1, "Aceitacao e obrigatoria."),
  registradoEm: z.string().datetime("Data deve estar em formato ISO."),
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export type CriarRefeicaoInput = z.infer<typeof criarRefeicaoSchema>;
