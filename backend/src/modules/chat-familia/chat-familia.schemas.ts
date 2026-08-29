import { z } from "zod";

const imagemSchema = z.object({
  mimeType: z
    .string()
    .regex(/^image\/(png|jpe?g|webp)$/i, "Imagem invalida."),
  base64: z
    .string()
    .min(1, "Imagem vazia.")
    .max(1_500_000, "Imagem muito grande."),
});

export const listarMensagensFamiliaSchema = z
  .object({
    idosoId: z.string().uuid("Idoso invalido."),
    outroUsuarioId: z.string().uuid("Contato invalido."),
    limite: z.coerce.number().int().min(1).max(100).default(50),
    antesDe: z.string().datetime({ offset: true }).optional(),
    antesId: z.string().uuid("Cursor invalido.").optional(),
  })
  .refine(
    (input) => Boolean(input.antesDe) === Boolean(input.antesId),
    {
      message: "O cursor da conversa esta incompleto.",
      path: ["antesDe"],
    },
  );

export const listarConversasFamiliaSchema = z.object({
  idosoId: z.string().uuid("Idoso invalido."),
});

export const criarMensagemFamiliaSchema = z
  .object({
    idosoId: z.string().uuid("Idoso invalido."),
    destinatarioId: z.string().uuid("Contato invalido."),
    mensagem: z.string().trim().max(2000, "Mensagem muito longa.").optional(),
    anexo: imagemSchema.optional(),
    clienteMensagemId: z
      .string()
      .trim()
      .min(8, "Identificador da mensagem invalido.")
      .max(128, "Identificador da mensagem invalido."),
  })
  .refine(
    (input) => Boolean(input.mensagem?.length) || Boolean(input.anexo),
    "Mensagem ou imagem e obrigatoria.",
  );

export const marcarMensagensLidasSchema = z.object({
  idosoId: z.string().uuid("Idoso invalido."),
  outroUsuarioId: z.string().uuid("Contato invalido."),
});

export const registrarDispositivoPushChatSchema = z.object({
  token: z
    .string()
    .trim()
    .min(20, "Token do dispositivo invalido.")
    .max(4096),
  plataforma: z.enum(["android", "ios", "web"]),
});

export const registrarPresencaChatSchema = z.object({});

export type ListarMensagensFamiliaInput = z.infer<
  typeof listarMensagensFamiliaSchema
>;
export type ListarConversasFamiliaInput = z.infer<
  typeof listarConversasFamiliaSchema
>;
export type CriarMensagemFamiliaInput = z.infer<
  typeof criarMensagemFamiliaSchema
>;
export type MarcarMensagensLidasInput = z.infer<
  typeof marcarMensagensLidasSchema
>;
export type RegistrarDispositivoPushChatInput = z.infer<
  typeof registrarDispositivoPushChatSchema
>;
