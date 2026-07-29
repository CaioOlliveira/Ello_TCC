import { z } from "zod";

export const perguntarIaSchema = z
  .object({
    usuarioId: z.string().uuid("Usuario invalido."),
    conversaId: z.string().uuid("Conversa invalida.").optional(),
    idosoId: z.string().uuid("Idoso invalido.").nullable().optional(),
    anexos: z
      .array(
        z.object({
          mimeType: z
            .string()
            .regex(/^image\/(png|jpe?g|webp)$/i, "Imagem invalida."),
          base64: z
            .string()
            .min(1, "Imagem vazia.")
            .max(4_500_000, "Imagem muito grande."),
        }),
      )
      .max(1, "Envie apenas uma imagem por mensagem.")
      .optional(),
    mensagem: z.string().trim().max(2000, "Mensagem muito longa."),
  })
  .refine(
    (input) => input.mensagem.length > 0 || (input.anexos?.length ?? 0) > 0,
    "Mensagem ou imagem e obrigatoria.",
  );

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
  idosoId: z.string().uuid("Idoso invalido.").optional(),
});

export const relatorioInicialIaSchema = z.object({
  usuarioId: z.string().uuid("Usuario invalido."),
  idosoId: z.string().uuid("Idoso invalido."),
});

export type PerguntarIaInput = z.infer<typeof perguntarIaSchema>;
export type ListarConversasIaInput = z.infer<typeof listarConversasIaSchema>;
export type CriarConversaIaInput = z.infer<typeof criarConversaIaSchema>;
export type ListarMensagensIaInput = z.infer<typeof listarMensagensIaSchema>;
export type RelatorioInicialIaInput = z.infer<typeof relatorioInicialIaSchema>;
