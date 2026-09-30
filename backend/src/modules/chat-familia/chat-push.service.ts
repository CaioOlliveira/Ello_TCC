import { randomUUID } from "node:crypto";

import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import type { PoolClient } from "pg";

import { env } from "../../config/env.js";
import { getPool } from "../../database/pool.js";

type ChatPushPayload = {
  mensagemId: string;
  idosoId: string;
  remetenteId: string;
  destinatarioId: string;
  remetenteNome: string;
  preview: string;
};

type PendingPushRow = {
  id: string;
  destinatario_id: string;
  mensagem_id: string;
  payload: ChatPushPayload;
  tentativas: number;
};

let dispatchInProgress = false;
let firebaseSetupLogged = false;
let pushTablesReady: Promise<void> | null = null;

const firebaseApp = () => {
  const raw = env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) return null;

  try {
    const existing = getApps()[0];
    if (existing) return existing;
    return initializeApp({ credential: cert(JSON.parse(raw)) });
  } catch (error) {
    if (!firebaseSetupLogged) {
      firebaseSetupLogged = true;
      console.error("Configuracao Firebase invalida para push do chat.", error);
    }
    return null;
  }
};

export const garantirTabelasPushChat = async () => {
  if (!pushTablesReady) {
    pushTablesReady = prepararTabelasPushChat().catch((error) => {
      pushTablesReady = null;
      throw error;
    });
  }
  await pushTablesReady;
};

async function prepararTabelasPushChat() {
  await getPool().query(`
    create table if not exists dispositivos_push (
      token text primary key,
      usuario_id uuid not null references usuarios(id) on delete cascade,
      plataforma varchar(16) not null,
      criado_em timestamptz not null default now(),
      atualizado_em timestamptz not null default now()
    )
  `);
  await getPool().query(`
    create index if not exists dispositivos_push_usuario_idx
      on dispositivos_push (usuario_id)
  `);
  await getPool().query(`
    create table if not exists eventos_push_chat (
      id uuid primary key,
      mensagem_id uuid not null unique references mensagens_chat_familia(id) on delete cascade,
      destinatario_id uuid not null references usuarios(id) on delete cascade,
      payload jsonb not null,
      tentativas integer not null default 0,
      proxima_tentativa_em timestamptz not null default now(),
      enviado_em timestamptz null,
      ultimo_erro text null,
      criado_em timestamptz not null default now()
    )
  `);
  await getPool().query(`
    create index if not exists eventos_push_chat_pendentes_idx
      on eventos_push_chat (proxima_tentativa_em asc)
      where enviado_em is null
  `);
}

export const registrarDispositivoPushChat = async ({
  usuarioId,
  token,
  plataforma,
}: {
  usuarioId: string;
  token: string;
  plataforma: string;
}) => {
  await garantirTabelasPushChat();
  await getPool().query(
    `
      insert into dispositivos_push (token, usuario_id, plataforma)
      values ($1, $2, $3)
      on conflict (token) do update
      set usuario_id = excluded.usuario_id,
          plataforma = excluded.plataforma,
          atualizado_em = now()
    `,
    [token, usuarioId, plataforma],
  );
};

export const removerDispositivoPushChat = async ({
  usuarioId,
  token,
}: {
  usuarioId: string;
  token: string;
}) => {
  await garantirTabelasPushChat();
  await getPool().query(
    "delete from dispositivos_push where token = $1 and usuario_id = $2",
    [token, usuarioId],
  );
};

export const enfileirarPushNovaMensagem = async (
  client: PoolClient,
  payload: ChatPushPayload,
) => {
  if (payload.remetenteId === payload.destinatarioId) return;

  await client.query(
    `
      insert into eventos_push_chat (
        id,
        mensagem_id,
        destinatario_id,
        payload
      )
      values ($1, $2, $3, $4::jsonb)
      on conflict (mensagem_id) do nothing
    `,
    [
      randomUUID(),
      payload.mensagemId,
      payload.destinatarioId,
      JSON.stringify(payload),
    ],
  );
};

const marcarEnviado = async (eventId: string) => {
  await getPool().query(
    `
      update eventos_push_chat
      set enviado_em = now(), ultimo_erro = null
      where id = $1
    `,
    [eventId],
  );
};

const reagendar = async (event: PendingPushRow, error: string) => {
  const delayMinutes = Math.min(30, 2 ** Math.min(event.tentativas, 5));
  await getPool().query(
    `
      update eventos_push_chat
      set ultimo_erro = $2,
          proxima_tentativa_em = now() + ($3 * interval '1 minute')
      where id = $1
    `,
    [event.id, error.slice(0, 500), delayMinutes],
  );
};

const proximoEvento = async (): Promise<PendingPushRow | null> => {
  const client = await getPool().connect();
  try {
    await client.query("begin");
    const result = await client.query<PendingPushRow>(`
      select id, destinatario_id, mensagem_id, payload, tentativas
      from eventos_push_chat
      where enviado_em is null
        and proxima_tentativa_em <= now()
      order by criado_em asc
      for update skip locked
      limit 1
    `);
    const event = result.rows[0];
    if (event) {
      await client.query(
        `
          update eventos_push_chat
          set tentativas = tentativas + 1,
              proxima_tentativa_em = now() + interval '5 minutes'
          where id = $1
        `,
        [event.id],
      );
      event.tentativas += 1;
    }
    await client.query("commit");
    return event ?? null;
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
};

const invalidTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

export const despacharPushsChatPendentes = async () => {
  if (dispatchInProgress || !firebaseApp()) return;
  dispatchInProgress = true;

  try {
    for (var processed = 0; processed < 20; processed++) {
      const event = await proximoEvento();
      if (!event) break;

      const devices = await getPool().query<{ token: string }>(
        "select token from dispositivos_push where usuario_id = $1",
        [event.destinatario_id],
      );
      const tokens = devices.rows.map((device) => device.token);
      if (tokens.length === 0) {
        await marcarEnviado(event.id);
        continue;
      }

      try {
        const payload = event.payload;
        const response = await getMessaging().sendEachForMulticast({
          tokens,
          notification: {
            title: `Mensagem de ${payload.remetenteNome}`,
            body: payload.preview,
          },
          data: {
            type: "chat_familia",
            mensagemId: payload.mensagemId,
            idosoId: payload.idosoId,
            peerId: payload.remetenteId,
          },
          android: {
            priority: "high",
            collapseKey: `chat-${payload.mensagemId}`,
            notification: { channelId: "ello_messages" },
          },
        });

        await finalizarTokensInvalidos(response.responses, tokens);
        if (response.successCount > 0 || response.failureCount == 0) {
          await marcarEnviado(event.id);
        } else {
          const error =
            response.responses[0]?.error?.message ?? "Falha ao enviar push.";
          await reagendar(event, error);
        }
      } catch (error) {
        await reagendar(
          event,
          error instanceof Error ? error.message : "Falha ao enviar push.",
        );
      }
    }
  } finally {
    dispatchInProgress = false;
  }
};

const finalizarTokensInvalidos = async (
  responses: Array<{ success: boolean; error?: { code?: string } }>,
  tokens: string[],
) => {
  const invalidTokens = responses.flatMap((response, index) =>
    !response.success && invalidTokenCodes.has(response.error?.code ?? "")
      ? [tokens[index]]
      : [],
  );

  if (invalidTokens.length === 0) return;
  await getPool().query(
    "delete from dispositivos_push where token = any($1::text[])",
    [invalidTokens],
  );
};

export const enviarPushMedicamento = async ({
  destinatarioId,
  titulo,
  mensagem,
  idosoId,
  solicitacaoId,
}: {
  destinatarioId: string;
  titulo: string;
  mensagem: string;
  idosoId: string;
  solicitacaoId: string;
}) => {
  const app = firebaseApp();
  if (!app) return;

  await garantirTabelasPushChat();
  const devices = await getPool().query<{ token: string }>(
    "select token from dispositivos_push where usuario_id = $1",
    [destinatarioId],
  );
  const tokens = devices.rows.map((device) => device.token);
  if (tokens.length === 0) return;

  const response = await getMessaging(app).sendEachForMulticast({
    tokens,
    notification: { title: titulo, body: mensagem },
    data: {
      type: "medicamento_cancelamento",
      idosoId,
      solicitacaoId,
    },
    android: {
      priority: "high",
      collapseKey: `medicamento-cancelamento-${solicitacaoId}`,
      notification: { channelId: "ello_messages" },
    },
  });
  await finalizarTokensInvalidos(response.responses, tokens);
};
