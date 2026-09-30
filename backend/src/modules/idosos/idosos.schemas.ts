import { z } from "zod";

const valoresSexo = ["Feminino", "Masculino", "Outro"] as const;

export const normalizarSexo = (value: unknown) => {
  if (typeof value !== "string") return value;
  const normalized = value
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "");

  if (!normalized) return undefined;
  if (["f", "fem", "feminino", "mulher", "idosa"].includes(normalized)) {
    return "Feminino";
  }
  if (["m", "masc", "masculino", "homem", "idoso"].includes(normalized)) {
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

const sexoSchema = z.preprocess(
  normalizarSexo,
  z.enum(valoresSexo, {
    invalid_type_error: "Sexo invalido.",
    required_error: "Sexo é obrigatório.",
  }),
);

export const idosoParamsSchema = z.object({
  idosoId: z.string().min(1, "Idoso é obrigatório."),
});

export const listarIdososQuerySchema = z.object({
  usuarioId: z.string().uuid("Usuario invalido.").optional(),
});

export const contatoEmergenciaSchema = z.object({
  nome: z.string().optional(),
  telefone: z.string().optional(),
  relacao: z.string().optional(),
  principal: z.boolean().optional(),
});

export const criarIdosoSchema = z.object({
  nomeCompleto: z.string().min(1, "Nome completo é obrigatório."),
  dataNascimento: z.string().date("Data de nascimento invalida.").optional(),
  urlFoto: z.string().nullable().optional(),
  pesoKg: z.number().positive().optional(),
  sexo: sexoSchema.optional(),
  tipoSanguineo: z
    .enum(["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"])
    .optional(),
  observacoesSaude: z.string().optional(),
  limitacoes: z.string().optional(),
  alergiasRestricoes: z.string().optional(),
  observacoesGerais: z.string().optional(),
  contatoEmergenciaNome: z.string().optional(),
  contatoEmergenciaTelefone: z.string().optional(),
  contatoEmergenciaParentesco: z.string().optional(),
  condicoesSaude: z.array(z.string().min(1)).optional(),
  monitoramentos: z.array(z.string().min(1)).optional(),
  contatoEmergencia: contatoEmergenciaSchema.optional(),
  criadoPorId: z.string().uuid("Usuario criador invalido.").optional(),
  ativo: z.boolean().optional(),
});

export const atualizarIdosoSchema = criarIdosoSchema.partial();

export type CriarIdosoInput = z.infer<typeof criarIdosoSchema>;
export type AtualizarIdosoInput = z.infer<typeof atualizarIdosoSchema>;
