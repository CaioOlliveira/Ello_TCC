import { z } from "zod";

export const insumoParamsSchema = z.object({
  insumoId: z.string().min(1, "Insumo e obrigatorio."),
});

export const criarInsumoSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  nome: z.string().min(1, "Nome é obrigatório."),
  tipoUnidade: z.string().min(1, "Tipo de unidade é obrigatório."),
  quantidadePorUnidade: z.number().positive().optional(),
  quantidadeUnidades: z.number().nonnegative(),
  alertaMinimoUnidades: z.number().nonnegative().optional(),
  consumoMedioDiario: z.number().nonnegative().optional(),
  dataValidade: z.string().date().optional(),
  observacoes: z.string().optional(),
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
