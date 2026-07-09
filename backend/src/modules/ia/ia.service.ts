import { randomUUID } from "node:crypto";

import { GoogleGenAI } from "@google/genai";

import { AppError } from "../../common/errors/app-error.js";
import { env } from "../../config/env.js";
import { getPool } from "../../database/pool.js";
import type {
  CriarConversaIaInput,
  ListarConversasIaInput,
  PerguntarIaInput,
} from "./ia.schemas.js";

const personalidade = `
Voce e a assistente auxiliar do app Ello, um aplicativo de cuidado e monitoramento de idosos. Sua funcao e ajudar cuidadores e familiares a organizar rotinas, entender registros basicos, lembrar tarefas e explicar informacoes do app de forma simples. Voce nao e medica e nao deve substituir atendimento profissional. Em situacoes de emergencia, sintomas graves ou duvidas clinicas importantes, oriente procurar um medico, hospital ou servico de emergencia. Responda sempre com linguagem clara, acolhedora e objetiva.
`.trim();

type ConversaIaRow = {
  id: string;
  usuario_id: string;
  idoso_id: string | null;
  titulo: string;
  criado_em: Date | string;
  atualizado_em: Date | string;
};

type MensagemIaRow = {
  id: string;
  conversa_id: string;
  remetente: "usuario" | "ia";
  conteudo: string;
  criado_em: Date | string;
};

export const iaService = {
  async garantirTabelas() {
    await garantirTabelasIa();
  },

  async listarConversas(input: ListarConversasIaInput) {
    await garantirTabelasIa();
    const params: unknown[] = [input.usuarioId];
    const idosoFilter = input.idosoId
      ? `and idoso_id = $${params.push(input.idosoId)}`
      : "";

    const result = await getPool().query<ConversaIaRow>(
      `
        select id, usuario_id, idoso_id, titulo, criado_em, atualizado_em
        from conversas_ia
        where usuario_id = $1
        ${idosoFilter}
        order by atualizado_em desc
      `,
      params,
    );

    return { dados: result.rows };
  },

  async criarConversa(input: CriarConversaIaInput) {
    await garantirTabelasIa();
    const result = await getPool().query<ConversaIaRow>(
      `
        insert into conversas_ia (id, usuario_id, idoso_id, titulo)
        values ($1, $2, $3, $4)
        returning id, usuario_id, idoso_id, titulo, criado_em, atualizado_em
      `,
      [randomUUID(), input.usuarioId, input.idosoId ?? null, input.titulo],
    );

    return { dados: result.rows[0] };
  },

  async listarMensagens(conversaId: string, usuarioId: string) {
    await garantirTabelasIa();
    await buscarConversaDoUsuario(conversaId, usuarioId);

    const result = await getPool().query<MensagemIaRow>(
      `
        select id, conversa_id, remetente, conteudo, criado_em
        from mensagens_ia
        where conversa_id = $1
        order by criado_em asc
      `,
      [conversaId],
    );

    return { dados: result.rows };
  },

  async perguntar(input: PerguntarIaInput) {
    await garantirTabelasIa();

    if (!isGeminiKeyConfigured(env.GEMINI_API_KEY)) {
      throw new AppError(
        "GEMINI_API_KEY_AUSENTE",
        "A IA ainda nao foi configurada. Adicione a chave do Gemini no .env do backend.",
        503,
      );
    }

    const conversa = input.conversaId
      ? await buscarConversaDoUsuario(input.conversaId, input.usuarioId)
      : (
          await this.criarConversa({
            usuarioId: input.usuarioId,
            idosoId: input.idosoId ?? null,
            titulo: "Novo chat",
          })
        ).dados;

    await salvarMensagem(conversa.id, "usuario", input.mensagem);
    await atualizarTituloSeNecessario(
      conversa.id,
      conversa.titulo,
      input.mensagem,
    );

    const historico = await buscarMensagens(conversa.id);
    const idosoId = input.idosoId ?? conversa.idoso_id;
    const [usuarioNome, idosoNome] = await Promise.all([
      buscarNomeUsuario(input.usuarioId),
      idosoId ? buscarNomeIdoso(idosoId) : Promise.resolve(null),
    ]);
    const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });

    try {
      const response = await ai.models.generateContent({
        model: env.GEMINI_MODEL,
        contents: [
          {
            role: "user",
            parts: [
              {
                text: montarPrompt(historico, usuarioNome, idosoNome),
              },
            ],
          },
        ],
      });

      const resposta = limparMarkdownResposta(response.text?.trim() ?? "");
      if (!resposta) {
        throw new AppError(
          "IA_RESPOSTA_VAZIA",
          "A IA nao conseguiu gerar uma resposta agora.",
          502,
        );
      }

      const mensagemIa = await salvarMensagem(conversa.id, "ia", resposta);
      const conversaAtualizada = await atualizarConversa(conversa.id);

      return { resposta, conversa: conversaAtualizada, mensagem: mensagemIa };
    } catch (error) {
      if (error instanceof AppError) throw error;

      throw new AppError(
        "IA_INDISPONIVEL",
        "Nao foi possivel falar com a IA agora. Tente novamente em instantes.",
        502,
      );
    }
  },
};

async function garantirTabelasIa() {
  await getPool().query(`
    create table if not exists conversas_ia (
      id uuid primary key,
      usuario_id uuid not null,
      idoso_id uuid null references fichas_idosos(id) on delete set null,
      titulo text not null default 'Novo chat',
      criado_em timestamptz not null default now(),
      atualizado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    alter table conversas_ia
      add column if not exists usuario_id uuid,
      add column if not exists idoso_id uuid,
      add column if not exists titulo text,
      add column if not exists criado_em timestamptz,
      add column if not exists atualizado_em timestamptz
  `);

  await getPool().query(`
    update conversas_ia
    set
      titulo = coalesce(titulo, 'Novo chat'),
      criado_em = coalesce(criado_em, now()),
      atualizado_em = coalesce(atualizado_em, criado_em, now())
  `);

  await getPool().query(`
    alter table conversas_ia
      alter column titulo set default 'Novo chat',
      alter column titulo set not null,
      alter column criado_em set default now(),
      alter column criado_em set not null,
      alter column atualizado_em set default now(),
      alter column atualizado_em set not null,
      alter column usuario_id set not null
  `);

  await getPool().query(`
    create table if not exists mensagens_ia (
      id uuid primary key,
      conversa_id uuid not null references conversas_ia(id) on delete cascade,
      remetente text not null check (remetente in ('usuario', 'ia')),
      conteudo text not null,
      criado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    alter table mensagens_ia
      add column if not exists conversa_id uuid,
      add column if not exists remetente text,
      add column if not exists conteudo text,
      add column if not exists criado_em timestamptz
  `);

  await getPool().query(`
    update mensagens_ia
    set criado_em = coalesce(criado_em, now())
  `);

  await getPool().query(`
    alter table mensagens_ia
      alter column conversa_id set not null,
      alter column remetente set not null,
      alter column conteudo set not null,
      alter column criado_em set default now(),
      alter column criado_em set not null
  `);

  await getPool().query(`
    create index if not exists idx_conversas_ia_usuario_atualizado
    on conversas_ia (usuario_id, atualizado_em desc)
  `);

  await getPool().query(`
    create index if not exists idx_mensagens_ia_conversa_criado
    on mensagens_ia (conversa_id, criado_em asc)
  `);
}

async function buscarNomeUsuario(usuarioId: string) {
  const result = await getPool().query<{ nome: string }>(
    "select nome from usuarios where id = $1 limit 1",
    [usuarioId],
  );
  return result.rows[0]?.nome ?? null;
}

async function buscarNomeIdoso(idosoId: string) {
  const result = await getPool().query<{ nome: string }>(
    "select nome_completo as nome from fichas_idosos where id = $1 limit 1",
    [idosoId],
  );
  return result.rows[0]?.nome ?? null;
}

async function buscarConversaDoUsuario(conversaId: string, usuarioId: string) {
  const result = await getPool().query<ConversaIaRow>(
    `
      select id, usuario_id, idoso_id, titulo, criado_em, atualizado_em
      from conversas_ia
      where id = $1 and usuario_id = $2
      limit 1
    `,
    [conversaId, usuarioId],
  );

  const conversa = result.rows[0];
  if (!conversa) {
    throw new AppError(
      "CONVERSA_IA_NAO_ENCONTRADA",
      "Conversa de IA nao encontrada.",
      404,
    );
  }

  return conversa;
}

async function buscarMensagens(conversaId: string) {
  const result = await getPool().query<MensagemIaRow>(
    `
      select id, conversa_id, remetente, conteudo, criado_em
      from mensagens_ia
      where conversa_id = $1
      order by criado_em asc
    `,
    [conversaId],
  );

  return result.rows;
}

async function salvarMensagem(
  conversaId: string,
  remetente: "usuario" | "ia",
  conteudo: string,
) {
  const result = await getPool().query<MensagemIaRow>(
    `
      insert into mensagens_ia (id, conversa_id, remetente, conteudo)
      values ($1, $2, $3, $4)
      returning id, conversa_id, remetente, conteudo, criado_em
    `,
    [randomUUID(), conversaId, remetente, conteudo],
  );

  await atualizarConversa(conversaId);
  return result.rows[0];
}

async function atualizarConversa(conversaId: string) {
  const result = await getPool().query<ConversaIaRow>(
    `
      update conversas_ia
      set atualizado_em = now()
      where id = $1
      returning id, usuario_id, idoso_id, titulo, criado_em, atualizado_em
    `,
    [conversaId],
  );

  return result.rows[0];
}

async function atualizarTituloSeNecessario(
  conversaId: string,
  tituloAtual: string,
  primeiraMensagem: string,
) {
  if (tituloAtual !== "Novo chat") return;

  const titulo = gerarTitulo(primeiraMensagem);
  await getPool().query(
    `
      update conversas_ia
      set titulo = $1, atualizado_em = now()
      where id = $2
    `,
    [titulo, conversaId],
  );
}

function gerarTitulo(mensagem: string) {
  const compacta = mensagem.replace(/\s+/g, " ").trim();
  if (compacta.length <= 44) return compacta;
  return `${compacta.slice(0, 44).trim()}...`;
}

function montarPrompt(
  mensagens: MensagemIaRow[],
  usuarioNome: string | null,
  idosoNome: string | null,
) {
  const remetenteUsuario = usuarioNome
    ? `Cuidador/familiar (${usuarioNome})`
    : "Cuidador/familiar";
  const historico = mensagens
    .map((mensagem) => {
      const remetente =
        mensagem.remetente === "usuario" ? remetenteUsuario : "Assistente";
      return `${remetente}: ${mensagem.conteudo}`;
    })
    .join("\n\n");

  return [
    personalidade,
    "Responda em portugues do Brasil.",
    usuarioNome
      ? `Voce esta conversando com o cuidador/familiar chamado ${usuarioNome}. Trate-o pelo primeiro nome quando fizer sentido, nunca por um identificador tecnico ou codigo.`
      : "Nao foi informado o nome do cuidador/familiar; nao invente um nome nem use codigos ou identificadores para se referir a ele.",
    idosoNome
      ? `A conversa esta relacionada ao idoso chamado ${idosoNome}.`
      : "",
    "Historico da conversa:",
    historico,
  ]
    .filter(Boolean)
    .join("\n\n");
}

function limparMarkdownResposta(texto: string) {
  return texto
    .replace(/\*\*(.*?)\*\*/g, "$1")
    .replace(/__(.*?)__/g, "$1")
    .replace(/^\s*[-*]\s+/gm, "- ")
    .replace(/(^|\s)\*(\S[^*]*?)\*(?=\s|[.,!?;:]|$)/g, "$1$2")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function isGeminiKeyConfigured(value?: string) {
  if (!value) return false;
  return !["COLOQUE_A_CHAVE_AQUI", "sua_chave_aqui"].includes(value.trim());
}
