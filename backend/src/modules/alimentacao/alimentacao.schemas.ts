import { z } from "zod";

export const alimentoConsumidoSchema = z.object({
  nome: z.string().min(1, "Nome do alimento e obrigatorio."),
  pesoGramas: z.number().nonnegative().optional(),
  calorias: z.number().nonnegative().optional(),
});

export const criarRefeicaoSchema = z.object({
  idosoId: z.string().min(1, "Idoso e obrigatorio."),
  tipoRefeicao: z.enum([
    "Cafe da manha",
    "Café da manhã",
    "Lanche da manha",
    "Lanche da manhã",
    "Almoco",
    "Almoço",
    "Lanche da tarde",
    "Jantar",
    "Ceia",
  ]),
  alimentos: z
    .array(alimentoConsumidoSchema)
    .min(1, "Informe ao menos um alimento."),
  aceitacao: z.string().min(1, "Aceitacao e obrigatoria."),
  registradoEm: z
    .string()
    .datetime("Data deve estar em formato ISO.")
    .optional(),
  dataConsumo: z.string().date("Data de consumo invalida.").optional(),
  horaConsumo: z
    .string()
    .regex(/^\d{2}:\d{2}$/, "Hora invalida.")
    .optional(),
  observacoes: z.string().optional(),
  registradoPorId: z.string().uuid().optional(),
});

export const atualizarRefeicaoSchema = criarRefeicaoSchema.partial();

export type CriarRefeicaoInput = z.infer<typeof criarRefeicaoSchema>;
export type AtualizarRefeicaoInput = z.infer<typeof atualizarRefeicaoSchema>;
