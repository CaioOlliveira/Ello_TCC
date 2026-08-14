import { z } from "zod";

const imagemSchema = z.object({
  mimeType: z.string().regex(/^image\/(png|jpe?g|webp)$/i, "Imagem invalida."),
  base64: z
    .string()
    .min(1, "Imagem vazia.")
    .max(4_500_000, "Imagem muito grande."),
});

export const listarMensagensFamiliaSchema = z.object({
  idosoId: z.string().uuid("Idoso invalido."),
  usuarioId: z.string().uuid("Usuario invalido."),
  outroUsuarioId: z.string().uuid("Contato invalido."),
});

export const criarMensagemFamiliaSchema = z
  .object({
    idosoId: z.string().uuid("Idoso invalido."),
    usuarioId: z.string().uuid("Usuario invalido."),
    destinatarioId: z.string().uuid("Contato invalido."),
    mensagem: z.string().trim().max(2000, "Mensagem muito longa.").optional(),
    anexo: imagemSchema.optional(),
  })
  .refine(
    (input) => Boolean(input.mensagem?.length) || Boolean(input.anexo),
    "Mensagem ou imagem e obrigatoria.",
  );

export type ListarMensagensFamiliaInput = z.infer<
  typeof listarMensagensFamiliaSchema
>;
export type CriarMensagemFamiliaInput = z.infer<
  typeof criarMensagemFamiliaSchema
>;
