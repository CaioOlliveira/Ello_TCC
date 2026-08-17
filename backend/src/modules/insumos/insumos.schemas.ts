import { z } from "zod";

export const insumoParamsSchema = z.object({
  insumoId: z.string().min(1, "Insumo e obrigatorio."),
});

export const removerInsumoQuerySchema = z.object({
  usuarioId: z.string().uuid("Usuário responsável inválido."),
});

export const listarInsumosQuerySchema = z.object({
  idosoId: z.string().uuid().optional(),
  filtro: z
    .enum(["todos", "acabando", "vencendo", "vencidos"])
    .default("todos"),
});

export const criarInsumoSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  nome: z.string().min(1, "Nome é obrigatório."),
  tipoUnidade: z.string().min(1, "Tipo de unidade é obrigatório."),
  quantidadePorUnidade: z.number().positive().nullable().optional(),
  quantidadeUnidades: z.number().nonnegative(),
  alertaMinimoUnidades: z.number().nonnegative().nullable().optional(),
  consumoMedioDiario: z.number().nonnegative().nullable().optional(),
  dataValidade: z.string().date().nullable().optional(),
  diasAlertaValidade: z.number().int().nonnegative().max(3650).optional(),
  fotoUrl: z.string().nullable().optional(),
  localArmazenamento: z.string().nullable().optional(),
  frequenciaUso: z.enum(["Diario", "Semanal", "Mensal"]).nullable().optional(),
  observacoes: z.string().nullable().optional(),
  usuarioId: z.string().uuid().optional(),
});

export const atualizarInsumoSchema = criarInsumoSchema.partial();

export const criarMovimentacaoInsumoSchema = z.object({
  tipo: z.enum(["entrada", "saida", "ajuste"]),
  quantidade: z.number().positive("Quantidade deve ser positiva."),
  motivo: z.string().min(1, "Motivo e obrigatorio."),
  observacoes: z.string().optional(),
  usuarioId: z.string().uuid().optional(),
});

export type CriarInsumoInput = z.infer<typeof criarInsumoSchema>;
export type AtualizarInsumoInput = z.infer<typeof atualizarInsumoSchema>;
export type CriarMovimentacaoInsumoInput = z.infer<
  typeof criarMovimentacaoInsumoSchema
>;
