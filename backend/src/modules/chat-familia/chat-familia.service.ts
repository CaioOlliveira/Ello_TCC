import { randomUUID } from "node:crypto";

import { AppError } from "../../common/errors/app-error.js";
import { getPool } from "../../database/pool.js";
import {
  despacharPushsChatPendentes,
  enfileirarPushNovaMensagem,
  garantirTabelasPushChat,
  registrarDispositivoPushChat,
} from "./chat-push.service.js";
import type {
  BuscarFotoContatoChatInput,
  CriarMensagemFamiliaInput,
  ListarConversasFamiliaInput,
  ListarMensagensFamiliaInput,
  MarcarMensagensLidasInput,
  RegistrarDispositivoPushChatInput,
} from "./chat-familia.schemas.js";

type ComUsuarioAutenticado<T> = T & { usuarioId: string };

type MensagemFamiliaRow = {
  id: string;
  idoso_id: string;
  remetente_id: string;
  destinatario_id: string;
  conteudo: string;
  anexo: { mimeType: string; base64: string } | null;
  cliente_mensagem_id: string;
  criado_em: Date | string;
  lido_em: Date | string | null;
  criada?: boolean;
};

type ConversaFamiliaRow = Record<string, unknown> & {
  usuario_id: string;
  usuario_nome: string;
  usuario_foto: string | null;
  funcao: string;
  mensagens_nao_lidas: number;
  ultima_mensagem_id: string | null;
  ultima_mensagem_conteudo: string | null;
  ultima_mensagem_remetente_id: string | null;
  ultima_mensagem_destinatario_id: string | null;
  ultima_mensagem_anexo: boolean | null;
  ultima_mensagem_em: Date | string | null;
};

let schemaReady: Promise<void> | null = null;

export const chatFamiliaService = {
  async listarConversas(
    input: ComUsuarioAutenticado<ListarConversasFamiliaInput>,
  ) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);

    const result = await getPool().query<ConversaFamiliaRow>(
      `
        with mensagens_do_usuario as (
          select
            m.id,
            m.idoso_id,
            m.remetente_id,
            m.destinatario_id,
            m.conteudo,
            m.anexo,
            m.criado_em,
            m.lido_em,
            m.destinatario_id as contato_id
          from mensagens_chat_familia m
          where m.idoso_id = $1
            and m.remetente_id = $2

          union all

          select
            m.id,
            m.idoso_id,
            m.remetente_id,
            m.destinatario_id,
            m.conteudo,
            m.anexo,
            m.criado_em,
            m.lido_em,
            m.remetente_id as contato_id
          from mensagens_chat_familia m
          where m.idoso_id = $1
            and m.destinatario_id = $2
        ),
        mensagens_ordenadas as (
          select
            *,
            row_number() over (
              partition by contato_id
              order by criado_em desc, id desc
            ) as ordem,
            (
              count(*) filter (
                where destinatario_id = $2 and lido_em is null
              ) over (partition by contato_id)
            )::int as mensagens_nao_lidas
          from mensagens_do_usuario
        ),
        membro_recente as (
          select distinct on (usuario_id)
            id,
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
        candidatos_base as (
          select f.criado_por_id as usuario_id, true as e_criador
          from fichas_idosos f
          where f.id = $1

          union

          select mf.usuario_id, false as e_criador
          from membros_ficha mf
          where mf.idoso_id = $1
            and mf.status = 'ativo'

          union

          select contato_id as usuario_id, false as e_criador
          from mensagens_ordenadas
        ),
        candidatos as (
          select usuario_id, bool_or(e_criador) as e_criador
          from candidatos_base
          group by usuario_id
        )
        select
          mr.id,
          $1::uuid as idoso_id,
          c.usuario_id,
          c.usuario_id as contato_id,
          u.nome as usuario_nome,
          u.nome as nome,
          case
            when u.url_foto is not null and length(u.url_foto) > 10000 then null
            else u.url_foto
          end as usuario_foto,
          case
            when u.url_foto is not null and length(u.url_foto) > 10000 then null
            else u.url_foto
          end as foto_url,
          u.telefone as usuario_telefone,
          null::text as usuario_sexo,
          coalesce(mr.funcao, 'cuidador') as funcao,
          mr.relacao,
          coalesce(mr.e_administrador, false) as e_administrador,
          coalesce(mr.permissoes, '{"visualizar":[],"editar":[]}'::jsonb) as permissoes,
          coalesce(mr.status, case when c.e_criador then 'ativo' else 'removido' end) as status,
          c.e_criador,
          ultima.id as ultima_mensagem_id,
          ultima.conteudo as ultima_mensagem_conteudo,
          ultima.remetente_id as ultima_mensagem_remetente_id,
          ultima.destinatario_id as ultima_mensagem_destinatario_id,
          (ultima.anexo is not null) as ultima_mensagem_anexo,
          ultima.criado_em as ultima_mensagem_em,
          case
            when ultima.id is null then null
            when length(trim(ultima.conteudo)) > 0 then ultima.conteudo
            when ultima.anexo is not null then 'Foto enviada'
            else ''
          end as ultima_mensagem_preview,
          coalesce(ultima.mensagens_nao_lidas, 0)::int as mensagens_nao_lidas,
          coalesce(ultima.mensagens_nao_lidas, 0)::int as nao_lidas,
          up.ultimo_visto_em,
          (up.ultimo_visto_em is not null and up.ultimo_visto_em >= now() - interval '75 seconds') as online
        from candidatos c
        join usuarios u on u.id = c.usuario_id
        left join membro_recente mr on mr.usuario_id = c.usuario_id
        left join mensagens_ordenadas ultima
          on ultima.contato_id = c.usuario_id
          and ultima.ordem = 1
        left join usuarios_presenca up on up.usuario_id = c.usuario_id
        where c.usuario_id != $2
        order by ultima.criado_em desc nulls last, ultima.id desc nulls last, u.nome asc
      `,
      [input.idosoId, input.usuarioId],
    );

    return { dados: result.rows.map(serializarConversaChatFamilia) };
  },

  async listarMensagens(
    input: ComUsuarioAutenticado<ListarMensagensFamiliaInput>,
  ) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);
    await validarContatoAtivoOuComHistorico(input);

    const result = await getPool().query<MensagemFamiliaRow>(
      `
        select
          id,
          idoso_id,
          remetente_id,
          destinatario_id,
          conteudo,
          anexo,
          cliente_mensagem_id,
          criado_em,
          lido_em
        from mensagens_chat_familia
        where idoso_id = $1
          and (
            (remetente_id = $2 and destinatario_id = $3)
            or (remetente_id = $3 and destinatario_id = $2)
          )
          and (
            $4::timestamptz is null
            or (criado_em, id) < ($4::timestamptz, $5::uuid)
          )
        order by criado_em desc, id desc
        limit $6
      `,
      [
        input.idosoId,
        input.usuarioId,
        input.outroUsuarioId,
        input.antesDe ?? null,
        input.antesId ?? null,
        input.limite + 1,
      ],
    );

    const temMais = result.rows.length > input.limite;
    const page = result.rows.slice(0, input.limite);
    const cursor = temMais ? page[page.length - 1] : null;

    return {
      dados: page.reverse().map(serializarDatasChatFamilia),
      paginacao: {
        temMais,
        proximoCursor: cursor
          ? {
              antesDe: serializarData(cursor.criado_em),
              antesId: cursor.id,
            }
          : null,
      },
    };
  },

  async marcarMensagensComoLidas(
    input: ComUsuarioAutenticado<MarcarMensagensLidasInput>,
  ) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);
    await validarContatoAtivoOuComHistorico(input);

    const result = await getPool().query(
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

    return { dados: { mensagensMarcadas: result.rowCount ?? 0 } };
  },

  async criarMensagem(input: ComUsuarioAutenticado<CriarMensagemFamiliaInput>) {
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

    const client = await getPool().connect();
    try {
      await client.query("begin");
      const result = await client.query<MensagemFamiliaRow>(
        `
          insert into mensagens_chat_familia (
            id,
            idoso_id,
            remetente_id,
            destinatario_id,
            conteudo,
            anexo,
            cliente_mensagem_id
          )
          values ($1, $2, $3, $4, $5, $6, $7)
          on conflict (remetente_id, cliente_mensagem_id) do update
          set cliente_mensagem_id = excluded.cliente_mensagem_id
          returning
            id,
            idoso_id,
            remetente_id,
            destinatario_id,
            conteudo,
            anexo,
            cliente_mensagem_id,
            criado_em,
            lido_em,
            (xmax = 0) as criada
        `,
        [
          randomUUID(),
          input.idosoId,
          input.usuarioId,
          input.destinatarioId,
          input.mensagem ?? "",
          input.anexo ? JSON.stringify(input.anexo) : null,
          input.clienteMensagemId,
        ],
      );
      const mensagem = result.rows[0];
      if (!mensagem) {
        throw new AppError(
          "CHAT_MENSAGEM_NAO_CRIADA",
          "Nao foi possivel criar a mensagem.",
          500,
        );
      }

      if (mensagem.criada) {
        const remetente = await client.query<{ nome: string }>(
          "select nome from usuarios where id = $1",
          [input.usuarioId],
        );
        await enfileirarPushNovaMensagem(client, {
          mensagemId: mensagem.id,
          idosoId: mensagem.idoso_id,
          remetenteId: mensagem.remetente_id,
          destinatarioId: mensagem.destinatario_id,
          remetenteNome: remetente.rows[0]?.nome ?? "Alguem",
          preview:
            mensagem.conteudo.trim() ||
            (mensagem.anexo ? "Foto enviada" : "Nova mensagem"),
        });
      }

      await client.query("commit");
      if (mensagem.criada) void despacharPushsChatPendentes();
      return { dados: serializarDatasChatFamilia(mensagem) };
    } catch (error) {
      await client.query("rollback").catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  },

  async buscarFotoContato(
    input: ComUsuarioAutenticado<BuscarFotoContatoChatInput>,
  ) {
    await garantirTabelaChatFamilia();
    await validarAcessoFicha(input.idosoId, input.usuarioId);
    await validarContatoAtivoOuComHistorico({
      idosoId: input.idosoId,
      usuarioId: input.usuarioId,
      outroUsuarioId: input.contatoId,
    });

    const result = await getPool().query<{ url_foto: string | null }>(
      "select url_foto from usuarios where id = $1",
      [input.contatoId],
    );

    return { dados: { urlFoto: result.rows[0]?.url_foto ?? null } };
  },

  async registrarDispositivoPush(
    input: ComUsuarioAutenticado<RegistrarDispositivoPushChatInput>,
  ) {
    await garantirTabelaChatFamilia();
    await registrarDispositivoPushChat(input);
  },

  async registrarPresenca({ usuarioId }: { usuarioId: string }) {
    await garantirTabelaChatFamilia();
    await getPool().query(
      `
        insert into usuarios_presenca (usuario_id, ultimo_visto_em)
        values ($1, now())
        on conflict (usuario_id) do update
        set ultimo_visto_em = excluded.ultimo_visto_em
      `,
      [usuarioId],
    );
    return { dados: { usuarioId, ultimoVistoEm: new Date().toISOString() } };
  },

  async apagarConversa(
    input: ComUsuarioAutenticado<MarcarMensagensLidasInput>,
  ) {
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
  if (!schemaReady) {
    schemaReady = prepararTabelaChatFamilia().catch((error) => {
      schemaReady = null;
      throw error;
    });
  }
  await schemaReady;
}

async function prepararTabelaChatFamilia() {
  await garantirCamposMembrosFicha();

  await getPool().query(`
    create table if not exists mensagens_chat_familia (
      id uuid primary key,
      idoso_id uuid not null references fichas_idosos(id) on delete cascade,
      remetente_id uuid not null references usuarios(id) on delete cascade,
      destinatario_id uuid not null references usuarios(id) on delete cascade,
      conteudo text not null default '',
      anexo jsonb null,
      cliente_mensagem_id varchar(128) null,
      criado_em timestamptz not null default now(),
      lido_em timestamptz null
    )
  `);
  await getPool().query(`
    alter table mensagens_chat_familia
      add column if not exists lido_em timestamptz null,
      add column if not exists cliente_mensagem_id varchar(128) null
  `);
  await getPool().query(`
    update mensagens_chat_familia
    set cliente_mensagem_id = id::text
    where cliente_mensagem_id is null
  `);
  await getPool().query(`
    alter table mensagens_chat_familia
      alter column cliente_mensagem_id set not null
  `);
  await getPool().query(`
    create unique index if not exists mensagens_chat_familia_cliente_unico_idx
      on mensagens_chat_familia (remetente_id, cliente_mensagem_id)
  `);
  await getPool().query(`
    create index if not exists mensagens_chat_familia_conversa_cursor_idx
      on mensagens_chat_familia (
        idoso_id,
        least(remetente_id, destinatario_id),
        greatest(remetente_id, destinatario_id),
        criado_em desc,
        id desc
      )
  `);
  await getPool().query(`
    create index if not exists mensagens_chat_familia_remetente_idx
      on mensagens_chat_familia (idoso_id, remetente_id, criado_em desc, id desc)
  `);
  await getPool().query(`
    create index if not exists mensagens_chat_familia_destinatario_idx
      on mensagens_chat_familia (idoso_id, destinatario_id, criado_em desc, id desc)
  `);
  await getPool().query(`
    create index if not exists mensagens_chat_familia_nao_lidas_v2_idx
      on mensagens_chat_familia (
        idoso_id,
        destinatario_id,
        remetente_id,
        criado_em desc
      )
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
  await garantirTabelasPushChat();
}

function serializarConversaChatFamilia(row: ConversaFamiliaRow) {
  const serializada = serializarDatasChatFamilia(row) as ConversaFamiliaRow;
  const ultimaMensagem = serializada.ultima_mensagem_id
    ? {
        id: serializada.ultima_mensagem_id,
        conteudo: serializada.ultima_mensagem_conteudo ?? "",
        remetente_id: serializada.ultima_mensagem_remetente_id,
        destinatario_id: serializada.ultima_mensagem_destinatario_id,
        criado_em: serializada.ultima_mensagem_em,
        possui_anexo: Boolean(serializada.ultima_mensagem_anexo),
      }
    : null;

  return {
    ...serializada,
    contato_id: serializada.usuario_id,
    nome: serializada.usuario_nome,
    foto_url: serializada.usuario_foto,
    nao_lidas: serializada.mensagens_nao_lidas,
    ultima_mensagem: ultimaMensagem,
  };
}

function serializarDatasChatFamilia<T>(value: T): T {
  if (value instanceof Date) return value.toISOString() as T;
  if (Array.isArray(value)) {
    return value.map(serializarDatasChatFamilia) as T;
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, item]) => [
        key,
        serializarDatasChatFamilia(item),
      ]),
    ) as T;
  }
  return value;
}

function serializarData(value: Date | string) {
  return value instanceof Date
    ? value.toISOString()
    : new Date(value).toISOString();
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
      "Usuario sem acesso a esta ficha.",
      403,
    );
  }
}

async function validarContatoAtivoOuComHistorico(
  input: ComUsuarioAutenticado<
    ListarMensagensFamiliaInput | MarcarMensagensLidasInput
  >,
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
      "Contato sem acesso a esta ficha e sem historico de conversa.",
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
      "Apenas o responsavel pela ficha pode apagar esta conversa.",
      403,
    );
  }
}

async function validarContatoRemovidoDaFicha(
  input: ComUsuarioAutenticado<MarcarMensagensLidasInput>,
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
