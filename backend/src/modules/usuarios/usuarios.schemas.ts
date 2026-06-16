import { z } from "zod";

export const criarUsuarioSchema = z.object({
  nome: z.string().min(1, "Nome é obrigatório."),
  email: z.string().email("E-mail inválido."),
  telefone: z.string().optional(),
  urlFoto: z.string().url("URL da foto inválida.").optional(),
  tipoUsuario: z.string().min(1, "Tipo de usuário é obrigatório."),
  senha: z.string().optional(),
});

export const atualizarUsuarioSchema = criarUsuarioSchema.partial();

export type CriarUsuarioInput = z.infer<typeof criarUsuarioSchema>;
export type AtualizarUsuarioInput = z.infer<typeof atualizarUsuarioSchema>;
