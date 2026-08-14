import { randomUUID } from "node:crypto";

import { AppError } from "../../common/errors/app-error.js";
import { getPool } from "../../database/pool.js";
import type {
  CriarMensagemFamiliaInput,
  ListarMensagensFamiliaInput,
} from "./chat-familia.schemas.js";

type MensagemFamiliaRow = {
  id: string;
  idoso_id: string;
  remetente_id: string;
  destinatario_id: string;
  conteudo: string;
  anexo: { mimeType: string; base64: string } | null;
  criado_em: Date | string;
};

export const chatFamiliaService = {
  async listarMensagens(input: ListarMensagensFamiliaInput) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);
    await validarAcessoFicha(input.idosoId, input.outroUsuarioId);

    const result = await getPool().query<MensagemFamiliaRow>(
      `
        select id, idoso_id, remetente_id, destinatario_id, conteudo, anexo, criado_em
        from mensagens_chat_familia
        where idoso_id = $1
          and (
            (remetente_id = $2 and destinatario_id = $3)
            or (remetente_id = $3 and destinatario_id = $2)
          )
        order by criado_em asc
      `,
      [input.idosoId, input.usuarioId, input.outroUsuarioId],
    );

    return { dados: result.rows };
  },

  async criarMensagem(input: CriarMensagemFamiliaInput) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);
    await validarAcessoFicha(input.idosoId, input.destinatarioId);

    if (input.usuarioId === input.destinatarioId) {
      throw new AppError(
        "CHAT_DESTINATARIO_INVALIDO",
        "Escolha outra pessoa para conversar.",
        400,
      );
    }

    const result = await getPool().query<MensagemFamiliaRow>(
      `
        insert into mensagens_chat_familia (
          id,
          idoso_id,
          remetente_id,
          destinatario_id,
          conteudo,
          anexo
        )
        values ($1, $2, $3, $4, $5, $6)
        returning id, idoso_id, remetente_id, destinatario_id, conteudo, anexo, criado_em
      `,
      [
        randomUUID(),
        input.idosoId,
        input.usuarioId,
        input.destinatarioId,
        input.mensagem ?? "",
        input.anexo ? JSON.stringify(input.anexo) : null,
      ],
    );

    return { dados: result.rows[0] };
  },
};

async function garantirTabelaChatFamilia() {
  await getPool().query(`
    create table if not exists mensagens_chat_familia (
      id uuid primary key,
      idoso_id uuid not null references fichas_idosos(id) on delete cascade,
      remetente_id uuid not null references usuarios(id) on delete cascade,
      destinatario_id uuid not null references usuarios(id) on delete cascade,
      conteudo text not null default '',
      anexo jsonb null,
      criado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    create index if not exists mensagens_chat_familia_conversa_idx
      on mensagens_chat_familia (
        idoso_id,
        least(remetente_id, destinatario_id),
        greatest(remetente_id, destinatario_id),
        criado_em
      )
  `);
}

async function validarAcessoFicha(idosoId: string, usuarioId: string) {
  const result = await getPool().query<{ permitido: boolean }>(
    `
      select (
        exists (
          select 1
          from fichas_idosos
          where id = $1 and criado_por_id = $2
        )
        or exists (
          select 1
          from membros_ficha
          where idoso_id = $1
            and usuario_id = $2
            and status = 'ativo'
        )
      ) as permitido
    `,
    [idosoId, usuarioId],
  );

  if (!result.rows[0]?.permitido) {
    throw new AppError(
      "CHAT_SEM_ACESSO",
      "Usuario sem acesso a esta ficha.",
      403,
    );
  }
}
