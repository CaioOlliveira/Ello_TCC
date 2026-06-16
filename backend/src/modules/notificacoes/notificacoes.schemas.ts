import { z } from "zod";

export const criarNotificacaoSchema = z.object({
  idosoId: z.string().uuid().optional(),
  usuarioId: z.string().uuid("Usuário inválido."),
  titulo: z.string().min(1, "Título é obrigatório."),
  mensagem: z.string().min(1, "Mensagem é obrigatória."),
  tipoNotificacao: z.string().min(1, "Tipo é obrigatório."),
  tipoEntidadeRelacionada: z.string().optional(),
  entidadeRelacionadaId: z.string().uuid().optional(),
  programadoPara: z.string().datetime().optional(),
});

export const atualizarNotificacaoSchema = criarNotificacaoSchema.partial();

export type CriarNotificacaoInput = z.infer<typeof criarNotificacaoSchema>;
export type AtualizarNotificacaoInput = z.infer<
  typeof atualizarNotificacaoSchema
>;
