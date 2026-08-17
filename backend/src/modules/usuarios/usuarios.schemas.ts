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

const valoresSexo = ["Feminino", "Masculino", "Outro"] as const;

const normalizarSexo = (value: unknown) => {
  if (typeof value !== "string") return value;
  const normalized = value
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "");

  if (!normalized) return undefined;
  if (["f", "fem", "feminino", "mulher"].includes(normalized)) {
    return "Feminino";
  }
  if (["m", "masc", "masculino", "homem"].includes(normalized)) {
    return "Masculino";
  }
  if (
    ["outro", "outra", "nao binario", "nao_binario", "nonbinary"].includes(
      normalized,
    )
  ) {
    return "Outro";
  }
  return value;
};

const sexoUsuarioSchema = z.preprocess(
  normalizarSexo,
  z.enum(valoresSexo, { invalid_type_error: "Sexo inválido." }),
);

export const criarUsuarioSchema = z.object({
  nome: z.string().min(1, "Nome é obrigatório."),
  email: z.string().email("E-mail inválido."),
  telefone: z.string().optional(),
  sexo: sexoUsuarioSchema.optional(),
  urlFoto: fotoUsuarioSchema.optional(),
  tipoUsuario: z.string().min(1, "Tipo de usuário é obrigatório."),
  senha: z.string().optional(),
});

export const atualizarUsuarioSchema = criarUsuarioSchema.partial();

export type CriarUsuarioInput = z.infer<typeof criarUsuarioSchema>;
export type AtualizarUsuarioInput = z.infer<typeof atualizarUsuarioSchema>;
