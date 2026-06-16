import { resolverUsuarioRegistroId } from "./usuario-demo.js";
import { getPool, isDatabaseEnabled } from "./pool.js";

type RegistrarHistoricoInput = {
  usuarioId?: string;
  idosoId?: string | null;
  acao: string;
  tipoEntidade: string;
  entidadeId: string;
  dadosAnteriores?: unknown;
  dadosNovos?: unknown;
};

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

  const registroUsuarioId = await resolverUsuarioRegistroId(usuarioId);

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
