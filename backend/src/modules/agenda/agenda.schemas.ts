import { z } from "zod";

export const criarEventoSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  titulo: z.string().min(1, "Título é obrigatório."),
  tipoEvento: z.string().min(1, "Tipo é obrigatório."),
  inicioEm: z.string().datetime("Início inválido."),
  fimEm: z.string().datetime("Fim inválido.").optional(),
  local: z.string().optional(),
  responsavelId: z.string().uuid().optional(),
  repeticao: z.string().optional(),
  lembreteMinutos: z.number().int().nonnegative().optional(),
  status: z.string().min(1).default("agendado"),
  observacoes: z.string().optional(),
  criadoPorId: z.string().uuid().optional(),
});

export const atualizarEventoSchema = criarEventoSchema.partial();

export type CriarEventoInput = z.infer<typeof criarEventoSchema>;
export type AtualizarEventoInput = z.infer<typeof atualizarEventoSchema>;
