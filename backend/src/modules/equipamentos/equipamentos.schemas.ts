import { z } from "zod";

export const criarEquipamentoSchema = z.object({
  idosoId: z.string().uuid("Idoso inválido."),
  nome: z.string().min(1, "Nome é obrigatório."),
  tipo: z.string().optional(),
  marca: z.string().optional(),
  modelo: z.string().optional(),
  numeroSerie: z.string().optional(),
  dataAquisicao: z.string().date().optional(),
  localGuardado: z.string().optional(),
  responsavelId: z.string().uuid().optional(),
  urlManual: z.string().url().optional(),
  frequenciaManutencaoDias: z.number().int().positive().optional(),
  proximaManutencaoEm: z.string().date().optional(),
  status: z.string().min(1).default("em_uso"),
  observacoesSeguranca: z.string().optional(),
});

export const atualizarEquipamentoSchema = criarEquipamentoSchema.partial();

export const criarManutencaoSchema = z.object({
  dataManutencao: z.string().date(),
  tipoManutencao: z.string().optional(),
  descricaoServico: z.string().optional(),
  pecasTrocadas: z.string().optional(),
  profissionalEmpresa: z.string().optional(),
  proximaManutencaoEm: z.string().date().optional(),
  custo: z.number().nonnegative().optional(),
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export type CriarEquipamentoInput = z.infer<typeof criarEquipamentoSchema>;
export type AtualizarEquipamentoInput = z.infer<
  typeof atualizarEquipamentoSchema
>;
export type CriarManutencaoInput = z.infer<typeof criarManutencaoSchema>;
