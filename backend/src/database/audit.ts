import { getPool, isDatabaseEnabled } from "./pool.js";
import { getRequestUserId } from "../common/auth/request-user.js";

type RegistrarHistoricoInput = {
  usuarioId?: string;
  idosoId?: string | null;
  acao: string;
  tipoEntidade: string;
  entidadeId: string;
  dadosAnteriores?: unknown;
  dadosNovos?: unknown;
};

// Usado por todas as consultas de histórico para descartar atribuições antigas
// a pessoas que não pertencem à ficha.
export const autorFichaHistoricoSql = `
  (h.usuario_id is null or exists (
    select 1 from fichas_idosos f
    where f.id::text = h.idoso_id::text
      and (f.criado_por_id::text = h.usuario_id::text or exists (
        select 1 from membros_ficha mf
        where mf.idoso_id = f.id and mf.usuario_id::text = h.usuario_id::text
          and mf.status = 'ativo'
      ))
  ))
`;

export const registrarHistorico = async ({
  usuarioId,
  idosoId,
  acao,
  tipoEntidade,
  entidadeId,
  dadosAnteriores,
  dadosNovos,
}: RegistrarHistoricoInput): Promise<void> => {
  if (!isDatabaseEnabled) return;

  // Um registro sem autor não deve receber o nome de outro usuário.
  const registroUsuarioId = getRequestUserId() ?? usuarioId ?? null;

  await getPool().query(
    `
      insert into historico_alteracoes (
        idoso_id,
        usuario_id,
        acao,
        tipo_entidade,
        entidade_id,
        dados_anteriores,
        dados_novos
      )
      values ($1, $2, $3, $4, $5, $6, $7)
    `,
    [
      idosoId ?? null,
      registroUsuarioId,
      acao,
      tipoEntidade,
      entidadeId,
      dadosAnteriores ? JSON.stringify(dadosAnteriores) : null,
      dadosNovos ? JSON.stringify(dadosNovos) : null,
    ],
  );
};
