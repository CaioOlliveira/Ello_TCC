import { z } from "zod";

export const idosoParamsSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
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
  nomeCompleto: z.string().min(1, "Nome completo e obrigatorio."),
  dataNascimento: z.string().date("Data de nascimento invalida.").optional(),
  urlFoto: z.string().url("URL da foto invalida.").optional(),
  sexo: z.string().optional(),
  observacoesSaude: z.string().optional(),
  limitacoes: z.string().optional(),
  alergiasRestricoes: z.string().optional(),
  observacoesGerais: z.string().optional(),
  observacoesEmergencia: z.string().optional(),
  condicoesSaude: z.array(z.string().min(1)).optional(),
  contatoEmergencia: contatoEmergenciaSchema.optional(),
  criadoPorId: z.string().uuid("Usuario criador invalido.").optional(),
  ativo: z.boolean().optional(),
});

export const atualizarIdosoSchema = criarIdosoSchema.partial();

export type CriarIdosoInput = z.infer<typeof criarIdosoSchema>;
export type AtualizarIdosoInput = z.infer<typeof atualizarIdosoSchema>;
