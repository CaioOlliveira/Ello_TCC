import { AppError } from "../common/errors/app-error.js";
import { getRequestUserId } from "../common/auth/request-user.js";
import { getPool } from "./pool.js";

export const resolverUsuarioRegistroId = async (
  usuarioId?: string,
): Promise<string> => {
  const authenticatedUserId = getRequestUserId();
  if (authenticatedUserId) return authenticatedUserId;
  if (usuarioId) {
    const usuario = await getPool().query<{ id: string }>(
      "select id from usuarios where id = $1 limit 1",
      [usuarioId],
    );

    if (usuario.rows[0]) return usuarioId;
  }

  throw new AppError(
    "USUARIO_REGISTRO_NAO_CONFIGURADO",
    "Não foi possível identificar quem fez a alteração. Entre novamente e tente de novo.",
    400,
  );
};
