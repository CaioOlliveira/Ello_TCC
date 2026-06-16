import { z } from "zod";

export const idosoParamsSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
});

export const criarIdosoSchema = z.object({
  nomeCompleto: z.string().min(1, "Nome completo é obrigatório."),
  dataNascimento: z.string().date("Data de nascimento inválida.").optional(),
  urlFoto: z.string().url("URL da foto inválida.").optional(),
  observacoesSaude: z.string().optional(),
  limitacoes: z.string().optional(),
  observacoesEmergencia: z.string().optional(),
  criadoPorId: z.string().uuid("Usuário criador inválido.").optional(),
  ativo: z.boolean().optional(),
});

export const atualizarIdosoSchema = criarIdosoSchema.partial();

export type CriarIdosoInput = z.infer<typeof criarIdosoSchema>;
export type AtualizarIdosoInput = z.infer<typeof atualizarIdosoSchema>;
