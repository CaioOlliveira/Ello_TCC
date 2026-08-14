import { z } from "zod";

export const permissoesSchema = z.object({
  visualizar: z.array(z.string().min(1)).default([]),
  editar: z.array(z.string().min(1)).default([]),
});

export const criarMembroSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  usuarioId: z.string().uuid("Usuário inválido."),
  funcao: z.string().min(1),
  relacao: z.string().optional(),
  podeEditar: z.boolean().optional(),
  podeConvidar: z.boolean().optional(),
  podeGerenciarMedicacoes: z.boolean().optional(),
  podeGerarRelatorios: z.boolean().optional(),
  eAdministrador: z.boolean().optional(),
  permissoes: permissoesSchema.optional(),
  status: z.string().min(1).default("ativo"),
});

export const atualizarMembroSchema = criarMembroSchema.partial();

export const listarParticipantesQuerySchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
});

export const registrarPresencaSchema = z.object({
  usuarioId: z.string().uuid("Usuário inválido."),
});

export type CriarMembroInput = z.infer<typeof criarMembroSchema>;
export type AtualizarMembroInput = z.infer<typeof atualizarMembroSchema>;
export type PermissoesInput = z.infer<typeof permissoesSchema>;
export type RegistrarPresencaInput = z.infer<typeof registrarPresencaSchema>;
