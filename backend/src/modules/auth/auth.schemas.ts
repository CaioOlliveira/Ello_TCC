import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email("E-mail inválido."),
  senha: z.string().min(1, "Senha é obrigatória."),
});

export const cadastroSchema = z.object({
  nome: z.string().min(1, "Nome é obrigatório."),
  email: z.string().email("E-mail inválido."),
  senha: z.string().min(6, "A senha deve ter pelo menos 6 caracteres."),
  telefone: z.string().optional(),
  tipoUsuario: z.string().min(1).default("cuidador"),
});

export const googleLoginSchema = z.object({
  idToken: z.string().min(1, "Token do Google é obrigatório."),
});

export const googleCadastroSchema = googleLoginSchema.extend({
  nome: z.string().min(1, "Nome é obrigatório."),
  telefone: z.string().optional(),
});

export const alterarSenhaSchema = z
  .object({
    usuarioId: z.string().uuid("Usuário inválido."),
    senhaAtual: z.string().min(1, "Senha atual é obrigatória."),
    novaSenha: z
      .string()
      .min(6, "A nova senha deve ter pelo menos 6 caracteres."),
    confirmarNovaSenha: z.string().min(1, "Confirme a nova senha."),
  })
  .refine((data) => data.novaSenha === data.confirmarNovaSenha, {
    message: "As senhas precisam ser iguais.",
    path: ["confirmarNovaSenha"],
  });

export type LoginInput = z.infer<typeof loginSchema>;
export type CadastroInput = z.infer<typeof cadastroSchema>;
export type GoogleLoginInput = z.infer<typeof googleLoginSchema>;
export type GoogleCadastroInput = z.infer<typeof googleCadastroSchema>;
export type AlterarSenhaInput = z.infer<typeof alterarSenhaSchema>;
