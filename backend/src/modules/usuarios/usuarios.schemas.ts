import { z } from "zod";

const fotoUsuarioSchema = z
  .string()
  .refine(
    (value) =>
      z.string().url().safeParse(value).success ||
      /^data:image\/(png|jpe?g|webp);base64,[a-z0-9+/]+={0,2}$/i.test(value),
    "URL da foto inválida.",
  )
  .nullable();

export const criarUsuarioSchema = z.object({
  nome: z.string().min(1, "Nome é obrigatório."),
  email: z.string().email("E-mail inválido."),
  telefone: z.string().optional(),
  urlFoto: fotoUsuarioSchema.optional(),
  tipoUsuario: z.string().min(1, "Tipo de usuário é obrigatório."),
  senha: z.string().optional(),
});

export const atualizarUsuarioSchema = criarUsuarioSchema.partial();

export type CriarUsuarioInput = z.infer<typeof criarUsuarioSchema>;
export type AtualizarUsuarioInput = z.infer<typeof atualizarUsuarioSchema>;
