import { randomUUID } from "node:crypto";

import { GoogleGenAI } from "@google/genai";

import { AppError } from "../../common/errors/app-error.js";
import { env } from "../../config/env.js";
import { getPool, isDatabaseEnabled } from "../../database/pool.js";
import type {
  CriarConversaIaInput,
  ListarMensagensIaInput,
  ListarConversasIaInput,
  PerguntarIaInput,
  RelatorioInicialIaInput,
} from "./ia.schemas.js";

const personalidade = `
Você é a assistente auxiliar do app Ello, um aplicativo de cuidado e monitoramento de idosos. Sua função é ajudar cuidadores e familiares a organizar rotinas, entender registros básicos, lembrar tarefas e explicar informações do app de forma simples. Você não é médica e não deve substituir atendimento profissional. Em situações de emergência, sintomas graves ou dúvidas clínicas importantes, oriente procurar um médico, hospital ou serviço de emergência. Responda sempre com linguagem clara, acolhedora e objetiva.
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
  anexos: Array<{ mimeType: string; base64: string }> | null;
  criado_em: Date | string;
};

type ContextoCacheItem = {
  expiresAt: number;
  value: Record<string, unknown> | null;
};

const contextoCache = new Map<string, ContextoCacheItem>();
const contextoTtlMs = 45_000;

export const iaService = {
  async garantirTabelas() {
    await garantirTabelasIa();
  },

  async listarConversas(input: ListarConversasIaInput) {
    await garantirTabelasIa();
    await validarAcessoContextoIdoso(input.idosoId, input.usuarioId);

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
    await validarAcessoContextoIdoso(input.idosoId, input.usuarioId);

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

  async listarMensagens(conversaId: string, input: ListarMensagensIaInput) {
    await garantirTabelasIa();
    const conversa = await buscarConversaDoUsuario(conversaId, input.usuarioId);
    validarConversaDoIdoso(conversa, input.idosoId);
    await validarAcessoContextoIdoso(conversa.idoso_id, input.usuarioId);

    const result = await getPool().query<MensagemIaRow>(
      `
        select id, conversa_id, remetente, conteudo, anexos, criado_em
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
        "A IA ainda não foi configurada. Adicione a chave do Gemini no .env do backend.",
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
    validarConversaDoIdoso(conversa, input.idosoId);

    const idosoId = input.idosoId ?? conversa.idoso_id;
    await validarAcessoContextoIdoso(idosoId, input.usuarioId);

    const conteudoUsuario = input.anexos?.length
      ? `${input.mensagem || "Analise esta imagem."}\n[imagem anexada]`
      : input.mensagem;

    await salvarMensagem(conversa.id, "usuario", conteudoUsuario, input.anexos);
    await atualizarTituloSeNecessario(
      conversa.id,
      conversa.titulo,
      input.mensagem || "Imagem anexada",
    );

    // Mantém o contexto da conversa útil sem deixar o prompt crescer sem
    // limite. Um histórico muito longo reduz o espaço disponível para a
    // resposta e pode fazer o modelo encerrar a frase antes de concluí-la.
    const historico = (await buscarMensagens(conversa.id)).slice(-12);
    const [usuarioNome, idosoNome, contextoIdoso] = await Promise.all([
      buscarNomeUsuario(input.usuarioId),
      idosoId ? buscarNomeIdoso(idosoId) : Promise.resolve(null),
      obterContextoInternoComFallback(idosoId, 2500, input.usuarioId),
    ]);
    const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });

    try {
      const prompt = montarPrompt(
        historico,
        usuarioNome,
        idosoNome,
        compactarContextoParaPrompt(contextoIdoso),
        Boolean(input.anexos?.length),
      );
      const partesImagem = montarPartesImagem(input.anexos);
      const configuracao = {
        // Em Gemini 2.5 o orçamento de saída também pode ser gasto no
        // raciocínio interno. Para este chat curto, desativamos esse
        // raciocínio e preservamos tokens para a resposta visível.
        maxOutputTokens: 1024,
        temperature: 0.4,
        ...(env.GEMINI_MODEL.startsWith("gemini-2.5")
          ? { thinkingConfig: { thinkingBudget: 0 } }
          : {}),
      };
      const gerarResposta = (instrucaoExtra = "") =>
        ai.models.generateContent({
          model: env.GEMINI_MODEL,
          config: configuracao,
          contents: [
            {
              role: "user",
              parts: [
                { text: `${prompt}${instrucaoExtra}` },
                ...partesImagem,
              ],
            },
          ],
        });

      let resposta = limparMarkdownResposta(
        (await gerarResposta()).text?.trim() ?? "",
      );

      // Nunca salvamos uma frase pela metade. Se o modelo consumiu seu
      // orçamento antes de terminar, repetimos a geração com uma instrução
      // explícita de resposta completa. Caso ainda falhe, o fallback abaixo
      // retorna uma orientação inteira em vez do trecho incompleto.
      if (resposta && !respostaEstaConcluida(resposta)) {
        const tentativaFinal = limparMarkdownResposta(
          (
            await gerarResposta(
              "\n\nIMPORTANTE: responda novamente à última pergunta do começo. Use poucas frases, mas termine todas as frases e encerre a resposta com ponto, interrogação ou exclamação.",
            )
          ).text?.trim() ?? "",
        );
        if (respostaEstaConcluida(tentativaFinal)) {
          resposta = tentativaFinal;
        }
      }

      if (!resposta || !respostaEstaConcluida(resposta)) {
        throw new AppError(
          "IA_RESPOSTA_INCOMPLETA",
          "A IA não conseguiu concluir a resposta agora.",
          502,
        );
      }

      const mensagemIa = await salvarMensagem(conversa.id, "ia", resposta);
      const conversaAtualizada = await atualizarConversa(conversa.id);

      return { resposta, conversa: conversaAtualizada, mensagem: mensagemIa };
    } catch (error) {
      console.error("[ia] Falha ao gerar resposta.", descreverErroIa(error));

      const respostaFallback = montarRespostaFallbackIa(
        input.mensagem,
        contextoIdoso,
      );
      if (respostaFallback) {
        const mensagemIa = await salvarMensagem(
          conversa.id,
          "ia",
          respostaFallback,
        );
        const conversaAtualizada = await atualizarConversa(conversa.id);

        return {
          resposta: respostaFallback,
          conversa: conversaAtualizada,
          mensagem: mensagemIa,
        };
      }

      if (error instanceof AppError) throw error;

      throw new AppError(
        "IA_INDISPONIVEL",
        "Não foi possível falar com a IA agora. Tente novamente em instantes.",
        502,
      );
    }
  },

  async obterRelatorioInicial(input: RelatorioInicialIaInput) {
    await validarAcessoContextoIdoso(input.idosoId, input.usuarioId);

    const contexto = await obterContextoInternoComFallback(
      input.idosoId,
      8000,
      input.usuarioId,
    );
    return montarRelatorioInicial(contexto);
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
      anexos jsonb,
      criado_em timestamptz not null default now()
    )
  `);

  await getPool().query(`
    alter table mensagens_ia
      add column if not exists conversa_id uuid,
      add column if not exists remetente text,
      add column if not exists conteudo text,
      add column if not exists anexos jsonb,
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
    create index if not exists idx_conversas_ia_usuario_idoso_atualizado
    on conversas_ia (usuario_id, idoso_id, atualizado_em desc)
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

async function validarAcessoContextoIdoso(
  idosoId?: string | null,
  usuarioId?: string | null,
) {
  if (!idosoId || !usuarioId || !isDatabaseEnabled) return;

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
      "IA_SEM_ACESSO_FICHA",
      "Usuário sem acesso a esta ficha.",
      403,
    );
  }
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
      "Conversa de IA não encontrada.",
      404,
    );
  }

  return conversa;
}

function validarConversaDoIdoso(
  conversa: ConversaIaRow,
  idosoId?: string | null,
) {
  if (!idosoId) return;
  if (conversa.idoso_id === idosoId) return;

  throw new AppError(
    "CONVERSA_IA_DE_OUTRA_FICHA",
    "Este chat pertence a outra ficha.",
    404,
  );
}

async function buscarMensagens(conversaId: string) {
  const result = await getPool().query<MensagemIaRow>(
    `
      select id, conversa_id, remetente, conteudo, anexos, criado_em
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
  anexos?: Array<{ mimeType: string; base64: string }>,
) {
  const result = await getPool().query<MensagemIaRow>(
    `
      insert into mensagens_ia (id, conversa_id, remetente, conteudo, anexos)
      values ($1, $2, $3, $4, $5)
      returning id, conversa_id, remetente, conteudo, anexos, criado_em
    `,
    [
      randomUUID(),
      conversaId,
      remetente,
      conteudo,
      anexos?.length ? JSON.stringify(anexos) : null,
    ],
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
  contextoInterno?: Record<string, unknown> | null,
  temImagem = false,
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
  const pessoaRelacionada = idosoNome
    ? descreverPessoaRelacionada(idosoNome, contextoInterno)
    : "";

  return [
    personalidade,
    "Responda em português do Brasil.",
    "Não comece toda resposta com 'Olá'. Cumprimente apenas quando fizer sentido natural no início de uma conversa.",
    "Seja breve: responda em 2 a 5 frases completas. Ao listar pontos, use no máximo 3 bullets completos. Só ultrapasse isso se o usuário pedir detalhes, relatório ou passo a passo.",
    "Conclua sempre as frases e a resposta. Não interrompa a resposta no meio de uma explicação; se precisar ser breve, encerre com uma conclusão útil.",
    "Priorize orientação prática e direta. Evite repetir muitos dados do contexto; cite apenas o que for essencial para responder.",
    usuarioNome
      ? `Você está conversando com o cuidador/familiar chamado ${usuarioNome}. Trate-o pelo primeiro nome quando fizer sentido, nunca por um identificador técnico ou código.`
      : "Não foi informado o nome do cuidador/familiar; não invente um nome nem use códigos ou identificadores para se referir a ele.",
    pessoaRelacionada,
    temImagem
      ? "A mensagem atual tem uma imagem anexada. Analise visualmente apenas o que for visível, descreva com cautela e não dê diagnóstico por imagem. Se houver risco, oriente procurar um profissional."
      : "",
    contextoInterno
      ? [
          "Contexto interno do app Ello, em JSON. Use estes dados para responder perguntas do cuidador, mas não diga que recebeu um JSON e não exponha IDs internos.",
          "Não invente dados ausentes. Quando os registros forem insuficientes, diga isso com naturalidade.",
          "Sobre chat da família: use somente mensagens presentes no contexto. Se o usuário perguntar sobre conversa privada entre outras pessoas que não aparece no contexto, diga que não tem acesso a essa conversa.",
          "Para dados clínicos, explique tendências básicas e recomende acompanhamento profissional quando houver risco, dúvida clínica ou valores preocupantes.",
          JSON.stringify(contextoInterno),
        ].join("\n")
      : "",
    "Historico da conversa:",
    historico,
  ]
    .filter(Boolean)
    .join("\n\n");
}

function descreverPessoaRelacionada(
  idosoNome: string,
  contextoInterno?: Record<string, unknown> | null,
) {
  const idoso = lerObjeto(contextoInterno?.idoso);
  const sexo = textoOuPadrao(idoso?.sexo, "").toLowerCase();

  if (sexo === "feminino") {
    return `A conversa está relacionada à idosa chamada ${idosoNome}.`;
  }
  if (sexo === "masculino") {
    return `A conversa está relacionada ao idoso chamado ${idosoNome}.`;
  }
  return `A conversa está relacionada à pessoa idosa chamada ${idosoNome}.`;
}

function montarPartesImagem(
  anexos?: Array<{ mimeType: string; base64: string }>,
) {
  return (anexos ?? []).map((anexo) => ({
    inlineData: {
      mimeType: anexo.mimeType,
      data: anexo.base64,
    },
  }));
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

function respostaEstaConcluida(texto: string) {
  return /[.!?…][\"')\]]*\s*$/.test(texto.trim());
}

async function obterContextoInternoComFallback(
  idosoId?: string | null,
  timeoutMs = 4000,
  usuarioId?: string | null,
) {
  if (!idosoId || !isDatabaseEnabled) return null;

  const cacheKey = `${idosoId}:${usuarioId ?? "anonimo"}`;
  const cached = contextoCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) return cached.value;

  try {
    const contexto = await withTimeout(
      montarContextoInternoIdoso(idosoId, usuarioId),
      timeoutMs,
    );
    contextoCache.set(cacheKey, {
      value: contexto,
      expiresAt: Date.now() + contextoTtlMs,
    });
    return contexto;
  } catch {
    return cached?.value ?? null;
  }
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number) {
  let timeout: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timeout = setTimeout(
          () => reject(new Error("CONTEXTO_IA_TIMEOUT")),
          timeoutMs,
        );
      }),
    ]);
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}

function montarRelatorioInicial(contexto: Record<string, unknown> | null) {
  const idoso = lerObjeto(contexto?.idoso);
  const nome = textoOuPadrao(
    idoso?.nome_completo,
    rotuloPessoaSelecionada(idoso?.sexo),
  );
  const primeiroNome = nome.split(" ")[0] || nome;
  const glicemia = lerObjeto(contexto?.glicemia);
  const resumoGlicemia = lerObjeto(glicemia?.resumo);
  const humor = lerArray(
    contexto?.humor && lerObjeto(contexto.humor)?.registrosRecentes,
  );
  const alimentacao = lerArray(
    contexto?.alimentacao && lerObjeto(contexto.alimentacao)?.registrosRecentes,
  );
  const insulina = lerArray(
    contexto?.insulina && lerObjeto(contexto.insulina)?.registrosRecentes,
  );
  const agenda = lerArray(contexto?.agenda);
  const equipamentos = lerObjeto(contexto?.equipamentos);
  const equipamentosCadastrados = lerArray(equipamentos?.cadastrados);

  return {
    mensagemInicial: `Olá, cuidador! Analisei os dados de ${nome} nos últimos dias e preparei um relatório geral. Quer dar uma olhada?`,
    secoes: [
      {
        tipo: "glicemia",
        titulo: "Glicemia",
        texto: montarTextoGlicemia(resumoGlicemia),
      },
      {
        tipo: "humor",
        titulo: "Humor e Comportamento",
        texto: montarTextoHumor(humor, agenda),
      },
      {
        tipo: "dica",
        titulo: "Dica do Assistente",
        texto: montarTextoDica({
          nome: primeiroNome,
          alimentacao,
          insulina,
          equipamentos: equipamentosCadastrados,
        }),
      },
    ],
  };
}

function rotuloPessoaSelecionada(sexo: unknown) {
  const normalized = textoOuPadrao(sexo, "").toLowerCase();
  if (normalized === "feminino") return "idosa selecionada";
  if (normalized === "masculino") return "idoso selecionado";
  return "pessoa idosa selecionada";
}

function montarRespostaFallbackIa(
  mensagem: string,
  contexto: Record<string, unknown> | null,
) {
  if (!contexto) return null;

  const normalizada = mensagem.toLowerCase();
  const relatorio = montarRelatorioInicial(contexto);
  const secoes = Array.isArray(relatorio.secoes) ? relatorio.secoes : [];
  const textoRelatorio = secoes
    .map((secao) => `${secao.titulo}: ${secao.texto}`)
    .join("\n\n");

  if (
    normalizada.includes("resumo") ||
    normalizada.includes("como") ||
    normalizada.includes("estado") ||
    normalizada.includes("idoso") ||
    normalizada.includes("glicemia") ||
    normalizada.includes("aliment")
  ) {
    return [
      "Consegui consultar os registros do app, mas a resposta completa da IA ficou indisponível por alguns instantes. Pelo resumo recente:",
      textoRelatorio,
      normalizada.includes("glicemia") || normalizada.includes("aliment")
        ? "Sobre alimentação e glicemia, registre a refeição e acompanhe as próximas medições. Se houver sintomas ou valores fora da faixa com frequência, procure orientação profissional."
        : "Use isso como apoio de acompanhamento, não como diagnóstico. Em caso de sintomas ou mudanças importantes, procure um profissional de saúde.",
    ].join("\n\n");
  }

  return [
    "Consegui consultar os registros recentes, mas a resposta completa da IA ficou indisponível por alguns instantes.",
    textoRelatorio,
    "Pode tentar perguntar de novo em seguida; se for algo urgente ou clínico, procure orientação profissional.",
  ].join("\n\n");
}

function descreverErroIa(error: unknown) {
  if (error instanceof AppError) {
    return {
      codigo: error.codigo,
      mensagem: error.message,
      status: error.statusCode,
    };
  }

  if (error && typeof error === "object") {
    const record = error as Record<string, unknown>;
    return {
      nome: record.name,
      mensagem: record.message,
      status: record.status,
      code: record.code,
    };
  }

  return { mensagem: String(error) };
}

function compactarContextoParaPrompt(contexto: Record<string, unknown> | null) {
  if (!contexto) return null;

  const glicemia = lerObjeto(contexto.glicemia);
  const insulina = lerObjeto(contexto.insulina);
  const alimentacao = lerObjeto(contexto.alimentacao);
  const hidratacao = lerObjeto(contexto.hidratacao);
  const humor = lerObjeto(contexto.humor);
  const medicamentos = lerObjeto(contexto.medicamentos);
  const equipamentos = lerObjeto(contexto.equipamentos);

  return sanitizarObjeto({
    geradoEm: contexto.geradoEm,
    janelaPrincipal: contexto.janelaPrincipal,
    idoso: contexto.idoso,
    glicemia: {
      resumo: glicemia?.resumo,
      registrosRecentes: lerArray(glicemia?.registrosRecentes).slice(0, 8),
    },
    insulina: {
      totalRegistrosRecentes: insulina?.totalRegistrosRecentes,
      registrosRecentes: lerArray(insulina?.registrosRecentes).slice(0, 6),
    },
    alimentacao: {
      totalRegistrosRecentes: alimentacao?.totalRegistrosRecentes,
      registrosRecentes: lerArray(alimentacao?.registrosRecentes).slice(0, 8),
    },
    hidratacao: {
      totalRegistrosRecentes: hidratacao?.totalRegistrosRecentes,
      registrosRecentes: lerArray(hidratacao?.registrosRecentes).slice(0, 6),
    },
    humor: {
      totalRegistrosRecentes: humor?.totalRegistrosRecentes,
      registrosRecentes: lerArray(humor?.registrosRecentes).slice(0, 8),
    },
    agenda: lerArray(contexto.agenda).slice(0, 8),
    medicamentos: {
      cadastrados: lerArray(medicamentos?.cadastrados).slice(0, 12),
      administracoesRecentes: lerArray(
        medicamentos?.administracoesRecentes,
      ).slice(0, 8),
    },
    insumos: lerArray(contexto.insumos).slice(0, 12),
    equipamentos: {
      cadastrados: lerArray(equipamentos?.cadastrados).slice(0, 12),
      manutencoesRecentes: lerArray(equipamentos?.manutencoesRecentes).slice(
        0,
        6,
      ),
    },
  }) as Record<string, unknown>;
}

function montarTextoGlicemia(resumo: Record<string, unknown> | null) {
  const total = numeroOuZero(resumo?.total);
  if (total === 0) {
    return "Ainda não há registros recentes suficientes para avaliar a glicemia. Registrar medições com frequência ajuda a identificar tendências.";
  }

  const media = numeroOuZero(resumo?.media);
  const acima180 = numeroOuZero(resumo?.acima180);
  const abaixo70 = numeroOuZero(resumo?.abaixo70);
  const foraDaFaixa = acima180 + abaixo70;
  const estabilidade = Math.max(
    0,
    Math.round(((total - foraDaFaixa) / total) * 100),
  );

  if (foraDaFaixa === 0) {
    return `O controle recente parece estável: foram ${total} medição(ões), média de ${media} mg/dL e nenhuma fora da faixa padrão registrada.`;
  }

  return `Foram ${total} medição(ões), média de ${media} mg/dL e ${estabilidade}% dentro da faixa padrão. Observe ${foraDaFaixa} registro(s) fora da faixa e acompanhe com um profissional se persistir.`;
}

function montarTextoHumor(
  humores: Record<string, unknown>[],
  agenda: Record<string, unknown>[],
) {
  if (humores.length === 0) {
    return "Ainda não há registros recentes de humor. Registrar mudanças de comportamento ajuda a cruzar informações com consultas, medicações e rotina.";
  }

  const ultimo = humores[0];
  const humorAtual = textoOuPadrao(ultimo.humor, "não informado");
  const observacao = textoOuPadrao(ultimo.observacoes, "");
  const compromisso = agenda.find(
    (item) => textoOuPadrao(item.titulo, "").length > 0,
  );
  const extra = compromisso
    ? ` Ha compromisso registrado: ${textoOuPadrao(compromisso.titulo, "agenda")}.`
    : "";
  const obs = observacao ? ` Observação recente: ${observacao}.` : "";

  return `O humor mais recente foi "${humorAtual}".${obs}${extra} Continue observando padrões entre rotina, descanso, alimentação e medicações.`;
}

function montarTextoDica({
  nome,
  alimentacao,
  insulina,
  equipamentos,
}: {
  nome: string;
  alimentacao: Record<string, unknown>[];
  insulina: Record<string, unknown>[];
  equipamentos: Record<string, unknown>[];
}) {
  const ultimaRefeicao = alimentacao[0];
  const ultimaInsulina = insulina[0];
  const equipamentoAtencao = equipamentos.find((item) => {
    const status = textoOuPadrao(item.status, "").toLowerCase();
    return status.includes("manut") || status.includes("fora");
  });

  if (ultimaInsulina) {
    return `Mantenha os registros de glicemia e insulina alinhados. Confira horários, alimentação e sintomas de ${nome} antes de tirar conclusões.`;
  }

  if (ultimaRefeicao) {
    return `Acompanhe se ${nome} está se alimentando e hidratando bem ao longo do dia. Pequenos registros consistentes deixam a rotina mais segura.`;
  }

  if (equipamentoAtencao) {
    return `Revise os equipamentos de apoio e mantenha manutenções em dia, principalmente os marcados com alerta ou fora de uso.`;
  }

  return `Continue registrando a rotina de ${nome}. Quanto mais completo o histórico, melhores ficam as análises do cuidado diário.`;
}

function lerObjeto(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function lerArray(value: unknown) {
  return Array.isArray(value)
    ? value.filter(
        (item): item is Record<string, unknown> =>
          Boolean(item) && typeof item === "object" && !Array.isArray(item),
      )
    : [];
}

function textoOuPadrao(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function numeroOuZero(value: unknown) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

async function montarContextoInternoIdoso(
  idosoId?: string | null,
  usuarioId?: string | null,
): Promise<Record<string, unknown> | null> {
  if (!idosoId || !isDatabaseEnabled) return null;

  const now = new Date();
  const desde30Dias = new Date(now);
  desde30Dias.setDate(desde30Dias.getDate() - 30);
  const desde14Dias = new Date(now);
  desde14Dias.setDate(desde14Dias.getDate() - 14);

  const [
    idoso,
    glicemia,
    insulina,
    alimentacao,
    hidratacao,
    humor,
    sono,
    pressao,
    oxigenacao,
    agenda,
    medicamentos,
    administracoesMedicamentos,
    insumos,
    equipamentos,
    manutencoesEquipamentos,
    historicoAlteracoes,
    conversasFamiliaDoUsuario,
  ] = await Promise.all([
    consultarLinhas(
      `
        select
          id,
          nome_completo,
          data_nascimento,
          extract(year from age(current_date, data_nascimento))::int as idade,
          peso_kg,
          sexo,
          tipo_sanguineo,
          observacoes_saude,
          limitacoes,
          alergias_restricoes,
          monitoramentos,
          (
            select conteudo
            from observacoes_gerais og
            where og.idoso_id = fichas_idosos.id
            order by registrado_em desc
            limit 1
          ) as ultima_observacao_geral
        from fichas_idosos
        where id = $1 and ativo = true
        limit 1
      `,
      [idosoId],
    ),
    consultarLinhas(
      `
        select
          valor_mg_dl,
          contexto_medicao,
          medido_em,
          sintomas,
          observacoes
        from registros_glicemia
        where idoso_id = $1 and medido_em >= $2
        order by medido_em desc
        limit 20
      `,
      [idosoId, desde30Dias.toISOString()],
    ),
    consultarLinhas(
      `
        select tipo_insulina, dose_unidades, aplicado_em, observacoes
        from registros_insulina
        where idoso_id = $1 and aplicado_em >= $2
        order by aplicado_em desc
        limit 12
      `,
      [idosoId, desde30Dias.toISOString()],
    ),
    consultarLinhas(
      `
        select
          tipo_refeicao,
          data_consumo,
          hora_consumo,
          alimentou_em,
          alimentos_consumidos,
          aceitacao,
          observacoes,
          concluida_em
        from registros_alimentacao
        where idoso_id = $1
          and coalesce(data_consumo, alimentou_em::date) >= $2::date
        order by coalesce(data_consumo, alimentou_em::date) desc,
                 coalesce(hora_consumo, alimentou_em::time) desc
        limit 18
      `,
      [idosoId, desde14Dias.toISOString().slice(0, 10)],
    ),
    consultarLinhas(
      `
        select quantidade_ml, registrado_em, observacoes
        from registros_hidratacao
        where idoso_id = $1 and registrado_em >= $2
        order by registrado_em desc
        limit 12
      `,
      [idosoId, desde14Dias.toISOString()],
    ),
    consultarLinhas(
      `
        select humor, data_humor, horario_regi, observacoes
        from registros_humor
        where idoso_id = $1 and data_humor >= $2::date
        order by data_humor desc, horario_regi desc
        limit 14
      `,
      [idosoId, desde30Dias.toISOString().slice(0, 10)],
    ),
    consultarLinhas(
      `
        select inicio_sono, fim_sono, qualidade, interrupcoes, observacoes
        from registros_sono
        where idoso_id = $1 and inicio_sono >= $2
        order by inicio_sono desc
        limit 8
      `,
      [idosoId, desde30Dias.toISOString()],
    ),
    consultarLinhas(
      `
        select sistolica, diastolica, frequencia_cardiaca, medido_em, observacoes
        from registros_pressao_arterial
        where idoso_id = $1 and medido_em >= $2
        order by medido_em desc
        limit 12
      `,
      [idosoId, desde30Dias.toISOString()],
    ),
    consultarLinhas(
      `
        select spo2, frequencia_cardiaca, registrado_em, observacoes
        from registros_oxigenacao
        where idoso_id = $1 and registrado_em >= $2
        order by registrado_em desc
        limit 12
      `,
      [idosoId, desde30Dias.toISOString()],
    ),
    consultarLinhas(
      `
        select
          titulo,
          tags,
          data_compromisso,
          hora_compromisso,
          local,
          frequencia,
          status,
          observacoes
        from tarefas
        where idoso_id = $1
          and data_compromisso >= current_date - interval '7 days'
        order by data_compromisso asc nulls last, hora_compromisso asc nulls last
        limit 14
      `,
      [idosoId],
    ),
    consultarLinhas(
      `
        select
          id,
          nome,
          dosagem,
          formato,
          instrucoes,
          data_inicio,
          data_fim,
          quantidade_estoque,
          unidade_estoque,
          alerta_estoque_baixo,
          ativo
        from medicamentos
        where idoso_id = $1
        order by ativo desc, nome asc
        limit 20
      `,
      [idosoId],
    ),
    consultarLinhas(
      `
        select
          m.nome as medicamento,
          am.horario_previsto,
          am.administrado_em,
          am.status,
          am.quantidade_dose,
          am.observacoes
        from administracoes_medicamentos am
        left join medicamentos m on m.id = am.medicamento_id
        where am.idoso_id = $1 and am.horario_previsto >= $2
        order by am.horario_previsto desc
        limit 16
      `,
      [idosoId, desde14Dias.toISOString()],
    ),
    consultarLinhas(
      `
        select
          nome,
          tipo_unidade,
          quantidade_unidades,
          alerta_minimo_unidades,
          consumo_medio_diario,
          frequencia_uso,
          data_validade,
          dias_alerta_validade,
          local_armazenamento,
          observacoes
        from insumos
        where idoso_id = $1
        order by nome asc
        limit 20
      `,
      [idosoId],
    ),
    consultarLinhas(
      `
        select
          id,
          nome,
          tipo,
          marca,
          modelo,
          ultima_manutencao_em,
          proxima_manutencao_em,
          status,
          frequencia_manutencao_dias,
          observacoes_seguranca
        from equipamentos
        where idoso_id = $1
        order by nome asc
        limit 20
      `,
      [idosoId],
    ),
    consultarLinhas(
      `
        select
          e.nome as equipamento,
          me.data_manutencao,
          me.tipo_manutencao,
          me.descricao_servico,
          me.problema_relatado,
          me.proxima_manutencao_em,
          me.observacoes
        from manutencoes_equipamentos me
        left join equipamentos e on e.id = me.equipamento_id
        where e.idoso_id = $1
        order by me.data_manutencao desc nulls last, me.criado_em desc nulls last
        limit 10
      `,
      [idosoId],
    ),
    consultarLinhas(
      `
        select tipo_entidade, acao, dados_anteriores, dados_novos, criado_em
        from historico_alteracoes
        where idoso_id = $1
          and criado_em >= $2
        order by criado_em desc
        limit 20
      `,
      [idosoId, desde14Dias.toISOString()],
    ),
    usuarioId
      ? consultarLinhas(
          `
            select
              case
                when m.remetente_id = $2 then destinatario.nome
                else remetente.nome
              end as conversa_com,
              case
                when m.remetente_id = $2 then 'usuario_atual'
                else 'outro_participante'
              end as remetente,
              m.conteudo,
              m.criado_em
            from mensagens_chat_familia m
            join usuarios remetente on remetente.id = m.remetente_id
            join usuarios destinatario on destinatario.id = m.destinatario_id
            where m.idoso_id = $1
              and (m.remetente_id = $2 or m.destinatario_id = $2)
            order by m.criado_em desc
            limit 24
          `,
          [idosoId, usuarioId],
        )
      : Promise.resolve([]),
  ]);

  const glicemias = sanitizarLinhas(glicemia);
  const valoresGlicemia = glicemias
    .map((registro) => Number(registro.valor_mg_dl))
    .filter((valor) => Number.isFinite(valor));

  return sanitizarObjeto({
    geradoEm: now.toISOString(),
    janelaPrincipal:
      "últimos 30 dias; alimentação, hidratação e histórico em janelas menores quando indicado",
    idoso: sanitizarLinhas(idoso)[0] ?? null,
    glicemia: {
      resumo: resumirGlicemia(valoresGlicemia),
      registrosRecentes: glicemias,
    },
    insulina: {
      totalRegistrosRecentes: insulina.length,
      registrosRecentes: sanitizarLinhas(insulina),
    },
    alimentacao: {
      totalRegistrosRecentes: alimentacao.length,
      registrosRecentes: sanitizarLinhas(alimentacao),
    },
    hidratacao: {
      totalRegistrosRecentes: hidratacao.length,
      registrosRecentes: sanitizarLinhas(hidratacao),
    },
    humor: {
      totalRegistrosRecentes: humor.length,
      registrosRecentes: sanitizarLinhas(humor),
    },
    sono: sanitizarLinhas(sono),
    pressaoArterial: sanitizarLinhas(pressao),
    oxigenacao: sanitizarLinhas(oxigenacao),
    agenda: sanitizarLinhas(agenda),
    medicamentos: {
      cadastrados: sanitizarLinhas(medicamentos).map((medicamento) => {
        const { id: _id, ...semId } = medicamento;
        return semId;
      }),
      administracoesRecentes: sanitizarLinhas(administracoesMedicamentos),
    },
    insumos: sanitizarLinhas(insumos),
    equipamentos: {
      cadastrados: sanitizarLinhas(equipamentos).map((equipamento) => {
        const { id: _id, ...semId } = equipamento;
        return semId;
      }),
      manutencoesRecentes: sanitizarLinhas(manutencoesEquipamentos),
    },
    historicoAlteracoesRecentes: sanitizarLinhas(historicoAlteracoes),
    conversasFamiliaDoUsuario: {
      regraPrivacidade:
        "Somente mensagens de conversas em que o usuário atual participa. Não há acesso a conversas privadas entre outras pessoas.",
      mensagensRecentes: sanitizarLinhas(conversasFamiliaDoUsuario),
    },
  }) as Record<string, unknown>;
}

async function consultarLinhas(sql: string, params: unknown[]) {
  try {
    const result = await getPool().query<Record<string, unknown>>(sql, params);
    return result.rows;
  } catch (error) {
    if (isErroTabelaOuColunaAusente(error)) return [];
    throw error;
  }
}

function isErroTabelaOuColunaAusente(error: unknown) {
  const code =
    typeof error === "object" && error !== null && "code" in error
      ? String((error as { code?: unknown }).code)
      : "";
  return ["42P01", "42703", "42883"].includes(code);
}

function sanitizarLinhas(rows: Record<string, unknown>[]) {
  return rows.map((row) => sanitizarObjeto(row) as Record<string, unknown>);
}

function sanitizarObjeto(value: unknown): unknown {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(sanitizarObjeto);
  if (!value || typeof value !== "object") {
    if (typeof value === "string") return sanitizarTexto(value);
    return value;
  }

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(
        ([key]) => !/url_foto|url_manual|foto_url|manual|base64/i.test(key),
      )
      .map(([key, item]) => [key, sanitizarObjeto(item)]),
  );
}

function sanitizarTexto(value: string) {
  const compactado = value.replace(/\s+/g, " ").trim();
  if (compactado.startsWith("data:application/pdf")) {
    return "[manual pdf anexado]";
  }
  if (compactado.length <= 500) return compactado;
  return `${compactado.slice(0, 500).trim()}...`;
}

function resumirGlicemia(valores: number[]) {
  if (valores.length === 0) {
    return {
      total: 0,
      media: null,
      menor: null,
      maior: null,
      abaixo70: 0,
      acima180: 0,
      acima250: 0,
    };
  }

  const soma = valores.reduce((total, valor) => total + valor, 0);
  return {
    total: valores.length,
    media: Math.round(soma / valores.length),
    menor: Math.min(...valores),
    maior: Math.max(...valores),
    abaixo70: valores.filter((valor) => valor < 70).length,
    acima180: valores.filter((valor) => valor > 180).length,
    acima250: valores.filter((valor) => valor > 250).length,
  };
}

function isGeminiKeyConfigured(value?: string) {
  if (!value) return false;
  return !["COLOQUE_A_CHAVE_AQUI", "sua_chave_aqui"].includes(value.trim());
}
