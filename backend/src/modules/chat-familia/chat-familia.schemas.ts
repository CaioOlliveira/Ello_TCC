import { z } from "zod";

const imagemSchema = z.object({
  mimeType: z.string().regex(/^image\/(png|jpe?g|webp)$/i, "Imagem inválida."),
  base64: z
    .string()
    .min(1, "Imagem vazia.")
    .max(4_500_000, "Imagem muito grande."),
});

export const listarMensagensFamiliaSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  usuarioId: z.string().uuid("Usuário inválido."),
  outroUsuarioId: z.string().uuid("Contato inválido."),
});

export const listarConversasFamiliaSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  usuarioId: z.string().uuid("Usuário inválido."),
});

export const criarMensagemFamiliaSchema = z
  .object({
    idosoId: z.string().uuid("Idoso inválido."),
    usuarioId: z.string().uuid("Usuário inválido."),
    destinatarioId: z.string().uuid("Contato inválido."),
    mensagem: z.string().trim().max(2000, "Mensagem muito longa.").optional(),
    anexo: imagemSchema.optional(),
  })
  .refine(
    (input) => Boolean(input.mensagem?.length) || Boolean(input.anexo),
    "Mensagem ou imagem é obrigatória.",
  );

export type ListarMensagensFamiliaInput = z.infer<
  typeof listarMensagensFamiliaSchema
>;
export type ListarConversasFamiliaInput = z.infer<
  typeof listarConversasFamiliaSchema
>;
export type CriarMensagemFamiliaInput = z.infer<
  typeof criarMensagemFamiliaSchema
>;
export type ApagarConversaFamiliaInput = z.infer<
  typeof listarMensagensFamiliaSchema
>;
