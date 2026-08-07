import { z } from "zod";

const textoOpcional = z.string().optional();
const textoOpcionalNulo = z.string().nullable().optional();

const toNumber = (value: unknown) => {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value === "number") return value;
  const parsed = Number(String(value).replace(",", "."));
  return Number.isNaN(parsed) ? value : parsed;
};

const normalizarEquipamento = (value: unknown) => {
  if (!value || typeof value !== "object" || Array.isArray(value)) return value;

  const input = value as Record<string, unknown>;
  return {
    ...input,
    idosoId: input.idosoId ?? input.idoso_id,
    dataAquisicao: input.dataAquisicao ?? input.data_aquisicao,
    validade: input.validade,
    ultimaManutencaoEm: input.ultimaManutencaoEm ?? input.ultima_manutencao_em,
    localGuardado: input.localGuardado ?? input.local_guardado,
    responsavelId: input.responsavelId ?? input.responsavel_id,
    criadoPorId: input.criadoPorId ?? input.criado_por_id,
    urlManual: input.urlManual ?? input.url_manual,
    urlFoto: Object.hasOwn(input, "urlFoto") ? input.urlFoto : input.url_foto,
    frequenciaManutencaoDias: toNumber(
      input.frequenciaManutencaoDias ?? input.frequencia_manutencao_dias,
    ),
    proximaManutencaoEm:
      input.proximaManutencaoEm ?? input.proxima_manutencao_em,
    observacoesSeguranca:
      input.observacoesSeguranca ?? input.observacoes_seguranca,
  };
};

const normalizarManutencao = (value: unknown) => {
  if (!value || typeof value !== "object" || Array.isArray(value)) return value;

  const input = value as Record<string, unknown>;
  return {
    ...input,
    dataManutencao: input.dataManutencao ?? input.data_manutencao,
    tipoManutencao: input.tipoManutencao ?? input.tipo_manutencao,
    descricaoServico: input.descricaoServico ?? input.descricao_servico,
    problemaRelatado: input.problemaRelatado ?? input.problema_relatado,
    pecasTrocadas: input.pecasTrocadas ?? input.pecas_trocadas,
    profissionalEmpresa:
      input.profissionalEmpresa ?? input.profissional_empresa,
    proximaManutencaoEm:
      input.proximaManutencaoEm ?? input.proxima_manutencao_em,
    custo: toNumber(input.custo),
    observacoes: input.observacoes,
    registradoPorId: input.registradoPorId ?? input.registrado_por_id,
  };
};

const equipamentoSchema = z.object({
  idosoId: z.string().uuid("Idoso invalido."),
  nome: z.string().min(1, "Nome e obrigatorio."),
  tipo: textoOpcional,
  marca: textoOpcional,
  modelo: textoOpcional,
  numeroSerie: textoOpcional,
  dataAquisicao: z.string().date().optional(),
  validade: z.string().date().optional(),
  ultimaManutencaoEm: z.string().date().optional(),
  localGuardado: textoOpcional,
  responsavelId: z.string().uuid().optional(),
  criadoPorId: z.string().uuid().optional(),
  urlManual: textoOpcional,
  urlFoto: textoOpcionalNulo,
  frequenciaManutencaoDias: z.number().int().positive().optional(),
  proximaManutencaoEm: z.string().date().optional(),
  status: z.string().min(1).default("Em uso"),
  observacoesSeguranca: textoOpcional,
});

export const criarEquipamentoSchema = z.preprocess(
  normalizarEquipamento,
  equipamentoSchema,
);

export const atualizarEquipamentoSchema = z.preprocess(
  normalizarEquipamento,
  equipamentoSchema.partial(),
);

const manutencaoSchema = z.object({
  dataManutencao: z.string().date(),
  tipoManutencao: textoOpcional,
  descricaoServico: textoOpcional,
  problemaRelatado: textoOpcional,
  pecasTrocadas: textoOpcional,
  profissionalEmpresa: textoOpcional,
  proximaManutencaoEm: z.string().date().optional(),
  custo: z.number().nonnegative().optional(),
  observacoes: textoOpcional,
  registradoPorId: z.string().uuid().optional(),
});

export const criarManutencaoSchema = z.preprocess(
  normalizarManutencao,
  manutencaoSchema,
);

export type CriarEquipamentoInput = z.infer<typeof criarEquipamentoSchema>;
export type AtualizarEquipamentoInput = z.infer<
  typeof atualizarEquipamentoSchema
>;
export type CriarManutencaoInput = z.infer<typeof criarManutencaoSchema>;
