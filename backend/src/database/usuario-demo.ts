import { AppError } from "../common/errors/app-error.js";
import { env } from "../config/env.js";
import { getPool } from "./pool.js";

export const resolverUsuarioRegistroId = async (
  usuarioId?: string,
): Promise<string> => {
  if (usuarioId) {
    const usuario = await getPool().query<{ id: string }>(
      "select id from usuarios where id = $1 limit 1",
      [usuarioId],
    );

    if (usuario.rows[0]) return usuarioId;
  }

  if (env.DEMO_USUARIO_ID) return env.DEMO_USUARIO_ID;

  const result = await getPool().query<{ id: string }>(
    "select id from usuarios order by criado_em asc limit 1",
  );

  const primeiroUsuario = result.rows[0];

  if (!primeiroUsuario) {
    throw new AppError(
      "USUARIO_REGISTRO_NAO_CONFIGURADO",
      "Nenhum usuário encontrado para registrar a ação. Envie registradoPorId ou configure DEMO_USUARIO_ID.",
      400,
    );
  }

  return primeiroUsuario.id;
};
