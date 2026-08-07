import { z } from "zod";

const tiposHistorico = [
  "insumos",
  "alimentacao",
  "humor",
  "equipamentos",
  "medicamentos",
  "temperatura",
  "agenda",
  "glicemia",
  "pressao",
  "oxigenacao",
] as const;

type TipoHistorico = (typeof tiposHistorico)[number];

const aliasesTipoHistorico: Record<string, TipoHistorico> = {
  insumo: "insumos",
  refeicoes: "alimentacao",
  refeicao: "alimentacao",
  alimentacoes: "alimentacao",
  humores: "humor",
  equipamento: "equipamentos",
  remedios: "medicamentos",
  remedio: "medicamentos",
  medicamento: "medicamentos",
  temperaturas: "temperatura",
  compromissos: "agenda",
  tarefas: "agenda",
  glicemias: "glicemia",
  pressoes: "pressao",
  pressao_arterial: "pressao",
  "pressao-arterial": "pressao",
  oxigenacoes: "oxigenacao",
};

const historicoTipoSchema = z
  .string()
  .trim()
  .toLowerCase()
  .transform((tipo) => aliasesTipoHistorico[tipo] ?? tipo)
  .pipe(z.enum(tiposHistorico));

export const listarHistoricoQuerySchema = z.object({
  idosoId: z.string().uuid("Idoso invalido."),
  tipo: historicoTipoSchema,
  inicio: z.string().date("Data inicial invalida."),
  fim: z.string().date("Data final invalida."),
  limite: z.coerce.number().int().positive().max(200).default(100),
});

export type ListarHistoricoQuery = z.infer<typeof listarHistoricoQuerySchema>;
