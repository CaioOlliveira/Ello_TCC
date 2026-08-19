import { randomUUID } from "node:crypto";

import { AppError } from "../../common/errors/app-error.js";
import { getPool } from "../../database/pool.js";
import type {
  ApagarConversaFamiliaInput,
  CriarMensagemFamiliaInput,
  ListarConversasFamiliaInput,
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
  lido_em: Date | string | null;
};

export const chatFamiliaService = {
  async listarConversas(input: ListarConversasFamiliaInput) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);

    const result = await getPool().query<Record<string, unknown>>(
      `
        with pares_com_mensagem as (
          select
            case
              when remetente_id = $2 then destinatario_id
            else remetente_id
            end as usuario_id,
            max(criado_em) as ultima_mensagem_em,
            count(*) filter (
              where destinatario_id = $2
                and lido_em is null
            )::int as mensagens_nao_lidas
          from mensagens_chat_familia
          where idoso_id = $1
            and (remetente_id = $2 or destinatario_id = $2)
          group by 1
        ),
        membro_recente as (
          select distinct on (usuario_id)
            id,
            idoso_id,
            usuario_id,
            funcao,
            relacao,
            e_administrador,
            permissoes,
            status,
            criado_em
          from membros_ficha
          where idoso_id = $1
          order by usuario_id, criado_em desc
        ),
        candidatos as (
          select
            f.criado_por_id as usuario_id,
            null::timestamptz as ultima_mensagem_em,
            0::int as mensagens_nao_lidas,
            true as e_criador
          from fichas_idosos f
          where f.id = $1

          union

          select
            mf.usuario_id,
            null::timestamptz as ultima_mensagem_em,
            0::int as mensagens_nao_lidas,
            false as e_criador
          from membros_ficha mf
          where mf.idoso_id = $1
            and mf.status = 'ativo'

          union

          select
            usuario_id,
            ultima_mensagem_em,
            mensagens_nao_lidas,
            false as e_criador
          from pares_com_mensagem
        )
        select distinct on (c.usuario_id)
          mr.id,
          $1::uuid as idoso_id,
          c.usuario_id,
          u.nome as usuario_nome,
          u.url_foto as usuario_foto,
          u.telefone as usuario_telefone,
          u.sexo as usuario_sexo,
          coalesce(mr.funcao, 'cuidador') as funcao,
          mr.relacao,
          coalesce(mr.e_administrador, false) as e_administrador,
          coalesce(mr.permissoes, '{"visualizar":[],"editar":[]}'::jsonb) as permissoes,
          coalesce(mr.status, case when c.e_criador then 'ativo' else 'removido' end) as status,
          c.e_criador,
          c.ultima_mensagem_em,
          (
            select case
              when length(trim(m.conteudo)) > 0 then m.conteudo
              when m.anexo is not null then 'Foto enviada'
              else ''
            end
            from mensagens_chat_familia m
            where m.idoso_id = $1
              and (
                (m.remetente_id = $2 and m.destinatario_id = c.usuario_id)
                or (m.remetente_id = c.usuario_id and m.destinatario_id = $2)
              )
            order by m.criado_em desc
            limit 1
          ) as ultima_mensagem_preview,
          coalesce(c.mensagens_nao_lidas, 0)::int as mensagens_nao_lidas,
          up.ultimo_visto_em,
          (up.ultimo_visto_em is not null and up.ultimo_visto_em >= now() - interval '75 seconds') as online
        from candidatos c
        join usuarios u on u.id = c.usuario_id
        left join membro_recente mr on mr.usuario_id = c.usuario_id
        left join usuarios_presenca up on up.usuario_id = c.usuario_id
        where c.usuario_id != $2
        order by c.usuario_id, c.ultima_mensagem_em desc nulls last
      `,
      [input.idosoId, input.usuarioId],
    );

    return { dados: result.rows };
  },

  async listarMensagens(input: ListarMensagensFamiliaInput) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);
    await validarContatoAtivoOuComHistorico(input);

    await getPool().query(
      `
        update mensagens_chat_familia
        set lido_em = now()
        where idoso_id = $1
          and remetente_id = $3
          and destinatario_id = $2
          and lido_em is null
      `,
      [input.idosoId, input.usuarioId, input.outroUsuarioId],
    );

    const result = await getPool().query<MensagemFamiliaRow>(
      `
        select id, idoso_id, remetente_id, destinatario_id, conteudo, anexo, criado_em, lido_em
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
        returning id, idoso_id, remetente_id, destinatario_id, conteudo, anexo, criado_em, lido_em
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

  async apagarConversa(input: ApagarConversaFamiliaInput) {
    await garantirTabelaChatFamilia();
    await validarResponsavelFicha(input.idosoId, input.usuarioId);
    await validarContatoRemovidoDaFicha(input);

    await getPool().query(
      `
        delete from mensagens_chat_familia
        where idoso_id = $1
          and (
            (remetente_id = $2 and destinatario_id = $3)
            or (remetente_id = $3 and destinatario_id = $2)
          )
      `,
      [input.idosoId, input.usuarioId, input.outroUsuarioId],
    );
  },
};

async function garantirTabelaChatFamilia() {
  await garantirCamposMembrosFicha();

  await getPool().query(`
    create table if not exists mensagens_chat_familia (
      id uuid primary key,
      idoso_id uuid not null references fichas_idosos(id) on delete cascade,
      remetente_id uuid not null references usuarios(id) on delete cascade,
      destinatario_id uuid not null references usuarios(id) on delete cascade,
      conteudo text not null default '',
      anexo jsonb null,
      criado_em timestamptz not null default now(),
      lido_em timestamptz null
    )
  `);

  await getPool().query(`
    alter table mensagens_chat_familia
      add column if not exists lido_em timestamptz null
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

  await getPool().query(`
    create index if not exists mensagens_chat_familia_nao_lidas_idx
      on mensagens_chat_familia (idoso_id, destinatario_id, criado_em desc)
      where lido_em is null
  `);

  await getPool().query(`
    create table if not exists usuarios_presenca (
      usuario_id uuid primary key references usuarios(id) on delete cascade,
      ultimo_visto_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    create index if not exists idx_usuarios_presenca_ultimo_visto
      on usuarios_presenca (ultimo_visto_em desc)
  `);
}

async function garantirCamposMembrosFicha() {
  await getPool().query(`
    alter table membros_ficha
      add column if not exists e_administrador boolean not null default false,
      add column if not exists permissoes jsonb not null default '{}'::jsonb
  `);

  await getPool().query(`
    alter table membros_ficha
      alter column funcao drop not null
  `);

  await getPool().query(`
    create index if not exists idx_membros_ficha_idoso_status
      on membros_ficha (idoso_id, status)
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
      "Usuário sem acesso a esta ficha.",
      403,
    );
  }
}

async function validarContatoAtivoOuComHistorico(
  input: ListarMensagensFamiliaInput,
) {
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
        or exists (
          select 1
          from mensagens_chat_familia
          where idoso_id = $1
            and (
              (remetente_id = $3 and destinatario_id = $2)
              or (remetente_id = $2 and destinatario_id = $3)
            )
        )
      ) as permitido
    `,
    [input.idosoId, input.outroUsuarioId, input.usuarioId],
  );

  if (!result.rows[0]?.permitido) {
    throw new AppError(
      "CHAT_SEM_ACESSO",
      "Contato sem acesso a esta ficha e sem histórico de conversa.",
      403,
    );
  }
}

async function validarResponsavelFicha(idosoId: string, usuarioId: string) {
  const result = await getPool().query<{ permitido: boolean }>(
    `
      select exists (
        select 1
        from fichas_idosos
        where id = $1 and criado_por_id = $2
      ) as permitido
    `,
    [idosoId, usuarioId],
  );

  if (!result.rows[0]?.permitido) {
    throw new AppError(
      "CHAT_APAGAR_APENAS_RESPONSAVEL",
      "Apenas o responsável pela ficha pode apagar esta conversa.",
      403,
    );
  }
}

async function validarContatoRemovidoDaFicha(
  input: ApagarConversaFamiliaInput,
) {
  const result = await getPool().query<{
    eh_responsavel: boolean;
    vinculo_ativo_ou_pendente: boolean;
  }>(
    `
      select
        exists (
          select 1
          from fichas_idosos
          where id = $1 and criado_por_id = $2
        ) as eh_responsavel,
        exists (
          select 1
          from membros_ficha
          where idoso_id = $1
            and usuario_id = $2
            and status in ('ativo', 'pendente')
        ) as vinculo_ativo_ou_pendente
    `,
    [input.idosoId, input.outroUsuarioId],
  );

  const contato = result.rows[0];
  if (contato?.eh_responsavel || contato?.vinculo_ativo_ou_pendente) {
    throw new AppError(
      "CHAT_CONTATO_AINDA_NA_FICHA",
      "Remova o cuidador da ficha antes de apagar esta conversa.",
      409,
    );
  }
}
