import { z } from "zod";

const normalizarTags = (value: unknown) => {
  if (Array.isArray(value)) {
    return value.map((item) => String(item)).filter(Boolean);
  }

  if (typeof value === "string" && value.trim().length > 0) {
    return [value.trim()];
  }

  return [];
};

const normalizarFrequencia = (value: unknown) => {
  if (typeof value !== "string") return value;

  const normalized = value.trim().toLowerCase();
  const values: Record<string, string> = {
    diario: "Diariamente",
    diariamente: "Diariamente",
    semanal: "Semanalmente",
    semanalmente: "Semanalmente",
    mensal: "Mensalmente",
    mensalmente: "Mensalmente",
    anual: "Anualmente",
    anualmente: "Anualmente",
    "nao repetir": "Não repetir",
    "não repetir": "Não repetir",
  };

  return values[normalized] ?? value;
};

const normalizarTarefaAgenda = (value: unknown) => {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return value;
  }

  const input = value as Record<string, unknown>;
  const inicioEm = input.inicioEm;
  const dataHora =
    typeof inicioEm === "string" ? new Date(inicioEm) : undefined;
  const dataCompromisso =
    input.dataCompromisso ??
    input.data_compromisso ??
    (dataHora && !Number.isNaN(dataHora.valueOf())
      ? dataHora.toISOString().slice(0, 10)
      : undefined);
  const horaCompromisso =
    input.horaCompromisso ??
    input.hora_compromisso ??
    (dataHora && !Number.isNaN(dataHora.valueOf())
      ? dataHora.toISOString().slice(11, 16)
      : undefined);
  const ativarLembrete = input.ativarLembrete ?? input.ativar_lembrete ?? false;

  return {
    ...input,
    idosoId: input.idosoId ?? input.idoso_id,
    dataCompromisso,
    horaCompromisso,
    local: input.local,
    atribuidoParaId:
      input.atribuidoParaId ??
      input.atribuido_para_id ??
      input.atruidoParaId ??
      input.atruido_para_id,
    responsavelId: input.responsavelId ?? input.responsavel_id,
    frequencia: normalizarFrequencia(input.frequencia ?? input.repeticao),
    tags: normalizarTags(input.tags ?? input.tipoEvento ?? input.tipo_evento),
    ativarLembrete,
    antecedenciaLembreteMinutos:
      input.antecedenciaLembreteMinutos ??
      input.antecedencia_lembrete_minutos ??
      input.lembreteMinutos,
    status: input.status,
    observacoes: input.observacoes,
    criadoPorId: input.criadoPorId ?? input.criado_por_id,
  };
};

const tarefaAgendaSchema = z.object({
  idosoId: z.string().uuid("Idoso invalido."),
  titulo: z.string().min(1, "Titulo e obrigatorio."),
  tags: z.array(z.string().min(1)).default([]),
  dataCompromisso: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Data invalida."),
  horaCompromisso: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/, "Hora invalida."),
  local: z.string().optional(),
  atribuidoParaId: z.string().uuid().optional(),
  responsavelId: z.string().uuid().optional(),
  frequencia: z.string().optional(),
  observacoes: z.string().optional(),
  ativarLembrete: z.boolean().default(false),
  antecedenciaLembreteMinutos: z.number().int().nonnegative().optional(),
  status: z.string().min(1).default("agendado"),
  criadoPorId: z.string().uuid().optional(),
});

export const criarEventoSchema = z.preprocess(
  normalizarTarefaAgenda,
  tarefaAgendaSchema,
);

export const atualizarEventoSchema = z.preprocess(
  normalizarTarefaAgenda,
  tarefaAgendaSchema.partial(),
);

export type CriarEventoInput = z.infer<typeof criarEventoSchema>;
export type AtualizarEventoInput = z.infer<typeof atualizarEventoSchema>;
