import { GoogleGenAI } from "@google/genai";

import { env } from "../../config/env.js";
import { getPool } from "../../database/pool.js";

export const dashboardService = {
  async obterResumo(idosoId: string) {
    const pool = getPool();

    const [
      idoso,
      ultimaGlicemia,
      alimentacaoHoje,
      proximosEventos,
      insumosAcabando,
      equipamentosManutencao,
      medicamentosAtivos,
    ] = await Promise.all([
      pool.query(
        "select * from fichas_idosos where id = $1 and ativo = true limit 1",
        [idosoId],
      ),
      pool.query(
        "select * from registros_glicemia where idoso_id = $1 order by medido_em desc limit 1",
        [idosoId],
      ),
      pool.query(
        `
          select count(*)::int as total
          from registros_alimentacao
          where idoso_id = $1
            and alimentou_em::date = current_date
        `,
        [idosoId],
      ),
      pool.query(
        `
          select *
          from eventos_calendario
          where idoso_id = $1
            and inicio_em >= now()
          order by inicio_em asc
          limit 5
        `,
        [idosoId],
      ),
      pool.query(
        `
          select *
          from insumos
          where idoso_id = $1
            and alerta_minimo_unidades is not null
            and quantidade_unidades <= alerta_minimo_unidades
          order by quantidade_unidades asc
          limit 5
        `,
        [idosoId],
      ),
      pool.query(
        `
          select *
          from equipamentos
          where idoso_id = $1
            and proxima_manutencao_em is not null
            and proxima_manutencao_em <= current_date + interval '15 days'
          order by proxima_manutencao_em asc
          limit 5
        `,
        [idosoId],
      ),
      pool.query(
        `
          select count(*)::int as total
          from medicamentos
          where idoso_id = $1 and ativo = true
        `,
        [idosoId],
      ),
    ]);

    return {
      idoso: idoso.rows[0] ?? null,
      ultimaGlicemia: ultimaGlicemia.rows[0] ?? null,
      alimentacaoHoje: {
        refeicoesRegistradas: alimentacaoHoje.rows[0]?.total ?? 0,
      },
      proximosEventos: proximosEventos.rows,
      insumosAcabando: insumosAcabando.rows,
      equipamentosManutencao: equipamentosManutencao.rows,
      medicamentos: {
        ativos: medicamentosAtivos.rows[0]?.total ?? 0,
      },
      dicaInformativa:
        "Acompanhe os registros e procure um profissional de saúde em caso de dúvidas ou alterações importantes.",
    };
  },

  async obterDicaDoDia(idosoId: string) {
    await garantirTabelaDicas();

    const today = new Date().toISOString().slice(0, 10);
    const cached = await getPool().query<{ texto: string }>(
      `
        select texto
        from dashboard_dicas_ia
        where idoso_id = $1 and data_dica = $2
        limit 1
      `,
      [idosoId, today],
    );

    if (cached.rows[0]?.texto) {
      return { texto: cached.rows[0].texto };
    }

    const texto = await gerarDicaDiaria(idosoId);
    await getPool().query(
      `
        insert into dashboard_dicas_ia (idoso_id, data_dica, texto)
        values ($1, $2, $3)
        on conflict (idoso_id, data_dica)
        do update set texto = excluded.texto, atualizado_em = now()
      `,
      [idosoId, today, texto],
    );

    return { texto };
  },
};

async function garantirTabelaDicas() {
  await getPool().query(`
    create table if not exists dashboard_dicas_ia (
      id bigserial primary key,
      idoso_id uuid not null references fichas_idosos(id) on delete cascade,
      data_dica date not null,
      texto text not null,
      criado_em timestamptz not null default now(),
      atualizado_em timestamptz not null default now(),
      unique (idoso_id, data_dica)
    )
  `);
}

async function gerarDicaDiaria(idosoId: string) {
  const fallback =
    "Incentive pequenas pausas, hidratacao e movimento leve ao longo do dia.";

  if (!isGeminiKeyConfigured(env.GEMINI_API_KEY)) {
    return fallback;
  }

  const contexto = await buscarContextoIdoso(idosoId);
  const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });

  try {
    const response = await ai.models.generateContent({
      model: env.GEMINI_MODEL,
      contents: [
        {
          role: "user",
          parts: [
            {
              text: [
                "Voce gera uma dica diaria curta para cuidadores no app Ello.",
                "A dica nao deve parecer conversa de chat e nao deve mencionar IA.",
                "Nao de diagnostico, prescricao ou orientacao medica individual.",
                "Escreva em portugues do Brasil, em uma frase de ate 110 caracteres.",
                contexto,
              ].join("\n"),
            },
          ],
        },
      ],
    });

    const texto = limparDica(response.text ?? "");
    return texto || fallback;
  } catch {
    return fallback;
  }
}

async function buscarContextoIdoso(idosoId: string) {
  const result = await getPool().query<{
    nome: string | null;
    idade: number | null;
    sexo: string | null;
    condicoes: unknown;
    limitacoes: string | null;
  }>(
    `
      select
        nome_completo as nome,
        case
          when data_nascimento is null then null
          else extract(year from age(current_date, data_nascimento))::int
        end as idade,
        sexo,
        observacoes_saude as condicoes,
        limitacoes
      from fichas_idosos
      where id = $1
      limit 1
    `,
    [idosoId],
  );

  const idoso = result.rows[0];
  if (!idoso) return "Contexto: idoso nao encontrado.";

  return [
    `Nome: ${idoso.nome ?? "nao informado"}.`,
    idoso.idade ? `Idade: ${idoso.idade}.` : "",
    idoso.sexo ? `Sexo: ${idoso.sexo}.` : "",
    idoso.condicoes ? `Condicoes: ${JSON.stringify(idoso.condicoes)}.` : "",
    idoso.limitacoes ? `Limitacoes: ${idoso.limitacoes}.` : "",
  ]
    .filter(Boolean)
    .join(" ");
}

function limparDica(texto: string) {
  return texto
    .replace(/\*\*(.*?)\*\*/g, "$1")
    .replace(/^\s*[-*]\s+/gm, "")
    .replace(/["“”]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 160);
}

function isGeminiKeyConfigured(value?: string) {
  if (!value) return false;
  return !["COLOQUE_A_CHAVE_AQUI", "sua_chave_aqui"].includes(value.trim());
}
