import { getPool, isDatabaseEnabled } from "./pool.js";

const performanceIndexes = [
  "create index concurrently if not exists idx_fichas_idosos_dono_ativo on fichas_idosos (dono_id, ativo)",
  "create index concurrently if not exists idx_membros_ficha_usuario_status_idoso on membros_ficha (usuario_id, status, idoso_id)",
  "create index concurrently if not exists idx_registros_alimentacao_idoso_data_hora on registros_alimentacao (idoso_id, data_consumo desc, hora_consumo desc)",
  "create index concurrently if not exists idx_registros_hidratacao_idoso_registrado on registros_hidratacao (idoso_id, registrado_em desc)",
  "create index concurrently if not exists idx_registros_humor_idoso_data_hora on registros_humor (idoso_id, data_humor desc, horario_regi desc)",
  "create index concurrently if not exists idx_gastos_ficha_idoso_data_criado on gastos_ficha (idoso_id, data_gasto desc, criado_em desc)",
  "create index concurrently if not exists idx_tarefas_idoso_data_hora on tarefas (idoso_id, data_compromisso asc, hora_compromisso asc)",
  "create index concurrently if not exists idx_medicamentos_idoso_ativo_nome on medicamentos (idoso_id, ativo desc, nome asc)",
  "create index concurrently if not exists idx_administracoes_medicamentos_idoso_previsto on administracoes_medicamentos (idoso_id, horario_previsto desc)",
  "create index concurrently if not exists idx_insumos_idoso_nome on insumos (idoso_id, nome asc)",
  "create index concurrently if not exists idx_equipamentos_idoso_nome on equipamentos (idoso_id, nome asc)",
  "create index concurrently if not exists idx_historico_alteracoes_idoso_criado on historico_alteracoes (idoso_id, criado_em desc)",
  "create index concurrently if not exists idx_registros_sono_idoso_inicio on registros_sono (idoso_id, inicio_sono desc)",
];

let ensurePromise: Promise<void> | null = null;

export function ensurePerformanceIndexes() {
  if (!isDatabaseEnabled) return Promise.resolve();
  ensurePromise ??= createPerformanceIndexes();
  return ensurePromise;
}

async function createPerformanceIndexes() {
  const pool = getPool();
  for (const statement of performanceIndexes) {
    try {
      await pool.query(statement);
    } catch (error) {
      if (!isIgnorableIndexError(error)) {
        console.warn("Nao foi possivel criar indice de performance.", error);
      }
    }
  }
}

function isIgnorableIndexError(error: unknown) {
  const code =
    typeof error === "object" && error !== null && "code" in error
      ? String((error as { code?: unknown }).code)
      : "";
  return ["42P01", "42703", "42P07", "0A000"].includes(code);
}
