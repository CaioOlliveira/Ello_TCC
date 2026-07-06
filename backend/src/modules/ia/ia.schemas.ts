import { z } from "zod";

export const perguntarIaSchema = z.object({
  usuarioId: z.string().uuid("Usuario invalido."),
  conversaId: z.string().uuid("Conversa invalida.").optional(),
  idosoId: z.string().uuid("Idoso invalido.").nullable().optional(),
  mensagem: z
    .string()
    .trim()
    .min(1, "Mensagem e obrigatoria.")
    .max(2000, "Mensagem muito longa."),
});

export const listarConversasIaSchema = z.object({
  usuarioId: z.string().uuid("Usuario invalido."),
  idosoId: z.string().uuid("Idoso invalido.").optional(),
});

export const criarConversaIaSchema = z.object({
  usuarioId: z.string().uuid("Usuario invalido."),
  idosoId: z.string().uuid("Idoso invalido.").nullable().optional(),
  titulo: z.string().trim().min(1).max(80).default("Novo chat"),
});

export const listarMensagensIaSchema = z.object({
  usuarioId: z.string().uuid("Usuario invalido."),
});

export type PerguntarIaInput = z.infer<typeof perguntarIaSchema>;
export type ListarConversasIaInput = z.infer<typeof listarConversasIaSchema>;
export type CriarConversaIaInput = z.infer<typeof criarConversaIaSchema>;
