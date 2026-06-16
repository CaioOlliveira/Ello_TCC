import { z } from "zod";

export const criarConviteSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  convidadoPorId: z.string().uuid("Usuário que convidou inválido.").optional(),
  codigo: z.string().min(4).optional(),
  funcaoInicial: z.string().min(1, "Função inicial é obrigatória."),
  expiraEm: z.string().datetime("Data de expiração inválida.").optional(),
  status: z.string().min(1).default("ativo"),
});

export const atualizarConviteSchema = criarConviteSchema.partial();

export const aceitarConviteSchema = z.object({
  codigo: z.string().min(1, "Código é obrigatório."),
  usadoPorId: z.string().uuid("Usuário inválido."),
});

export type CriarConviteInput = z.infer<typeof criarConviteSchema>;
export type AtualizarConviteInput = z.infer<typeof atualizarConviteSchema>;
export type AceitarConviteInput = z.infer<typeof aceitarConviteSchema>;
