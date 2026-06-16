import { z } from "zod";

export const criarMembroSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  usuarioId: z.string().uuid("Usuário inválido."),
  funcao: z.string().min(1),
  relacao: z.string().optional(),
  podeEditar: z.boolean().optional(),
  podeConvidar: z.boolean().optional(),
  podeGerenciarMedicacoes: z.boolean().optional(),
  podeGerarRelatorios: z.boolean().optional(),
  status: z.string().min(1).default("ativo"),
});

export const atualizarMembroSchema = criarMembroSchema.partial();

export type CriarMembroInput = z.infer<typeof criarMembroSchema>;
export type AtualizarMembroInput = z.infer<typeof atualizarMembroSchema>;
