import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email("E-mail invalido."),
  senha: z.string().min(1, "Senha e obrigatoria."),
});

export const cadastroSchema = z.object({
  nome: z.string().min(1, "Nome e obrigatorio."),
  email: z.string().email("E-mail invalido."),
  senha: z.string().min(6, "A senha deve ter pelo menos 6 caracteres."),
  telefone: z.string().optional(),
  tipoUsuario: z.string().min(1).default("cuidador"),
});

export type LoginInput = z.infer<typeof loginSchema>;
export type CadastroInput = z.infer<typeof cadastroSchema>;
