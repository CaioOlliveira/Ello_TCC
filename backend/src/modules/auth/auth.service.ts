import {
  createHash,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from "node:crypto";
import { OAuth2Client } from "google-auth-library";

import { AppError } from "../../common/errors/app-error.js";
import { getPool } from "../../database/pool.js";
import type {
  AlterarSenhaInput,
  CadastroInput,
  GoogleCadastroInput,
  GoogleLoginInput,
  LoginInput,
} from "./auth.schemas.js";

type UsuarioAuthRow = {
  id: string;
  nome: string;
  email: string;
  telefone?: string | null;
  sexo?: string | null;
  url_foto?: string | null;
  tipo_usuario: string;
  senha: string;
  criado_em?: Date;
  atualizado_em?: Date;
};

const senhaPrefixo = "scrypt";
const googleClient = new OAuth2Client();
const defaultGoogleClientIds = [
  "318821887059-iukcc2mai6klc7ml1a1h121ev37rvsvm.apps.googleusercontent.com",
  "318821887059-5s73kv24r25eg92265lc7anm68t7s21r.apps.googleusercontent.com",
];

const toUsuarioPublico = (usuario: UsuarioAuthRow) => ({
  id: usuario.id,
  nome: usuario.nome,
  email: usuario.email,
  telefone: usuario.telefone,
  sexo: usuario.sexo,
  urlFoto: usuario.url_foto,
  tipoUsuario: usuario.tipo_usuario,
  criadoEm: usuario.criado_em,
  atualizadoEm: usuario.atualizado_em,
});

const criarHashSenha = (senha: string) => {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(senha, salt, 64).toString("hex");
  return `${senhaPrefixo}$${salt}$${hash}`;
};

const compararSeguro = (a: string, b: string) => {
  const bufferA = Buffer.from(a);
  const bufferB = Buffer.from(b);

  if (bufferA.length !== bufferB.length) return false;
  return timingSafeEqual(bufferA, bufferB);
};

const senhaConfere = (senhaInformada: string, senhaArmazenada: string) => {
  const [prefixo, salt, hash] = senhaArmazenada.split("$");

  if (!salt || !hash) {
    return senhaInformada === senhaArmazenada;
  }

  if (prefixo === senhaPrefixo) {
    const hashInformado = scryptSync(senhaInformada, salt, 64).toString("hex");
    return compararSeguro(hashInformado, hash);
  }

  if (prefixo === "sha256") {
    const hashInformado = createHash("sha256")
      .update(`${salt}:${senhaInformada}`)
      .digest("hex");

    return compararSeguro(hashInformado, hash);
  }

  return false;
};

const buscarUsuarioPorEmail = async (email: string) => {
  const result = await getPool().query<UsuarioAuthRow>(
    "select * from usuarios where lower(email) = lower($1) limit 1",
    [email.trim()],
  );

  return result.rows[0];
};

const buscarUsuarioPorId = async (usuarioId: string) => {
  const result = await getPool().query<UsuarioAuthRow>(
    "select * from usuarios where id = $1 limit 1",
    [usuarioId],
  );

  return result.rows[0];
};

const googleAudiences = () => {
  const raw =
    process.env.GOOGLE_CLIENT_IDS ??
    process.env.GOOGLE_CLIENT_ID ??
    process.env.GOOGLE_WEB_CLIENT_ID ??
    defaultGoogleClientIds.join(",");

  return raw
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
};

const validarGoogleToken = async (idToken: string) => {
  const audiences = googleAudiences();

  if (audiences.length === 0) {
    throw new AppError(
      "GOOGLE_OAUTH_NAO_CONFIGURADO",
      "Login com Google ainda não foi configurado no servidor.",
      500,
    );
  }

  let ticket;
  try {
    ticket = await googleClient.verifyIdToken({
      idToken,
      audience: audiences,
    });
  } catch {
    throw new AppError(
      "GOOGLE_TOKEN_INVALIDO",
      "Não foi possível validar a conta Google.",
      401,
    );
  }
  const payload = ticket.getPayload();

  if (!payload?.email) {
    throw new AppError(
      "GOOGLE_TOKEN_INVALIDO",
      "Não foi possível validar a conta Google.",
      401,
    );
  }

  if (payload.email_verified !== true) {
    throw new AppError(
      "GOOGLE_EMAIL_NAO_VERIFICADO",
      "A conta Google precisa ter e-mail verificado.",
      401,
    );
  }

  return {
    email: payload.email.trim().toLowerCase(),
    nome: payload.name?.trim() || payload.email.split("@")[0],
    fotoUrl: payload.picture ?? null,
  };
};

export const authService = {
  status() {
    return {
      autenticacaoReal: true,
      mensagem: "Autenticacao por e-mail e senha habilitada.",
    };
  },

  async login(input: LoginInput) {
    const usuario = await buscarUsuarioPorEmail(input.email);

    if (!usuario || !senhaConfere(input.senha, usuario.senha)) {
      throw new AppError(
        "CREDENCIAIS_INVALIDAS",
        "E-mail ou senha incorretos.",
        401,
      );
    }

    return {
      usuario: toUsuarioPublico(usuario),
    };
  },

  async cadastrar(input: CadastroInput) {
    const usuarioExistente = await buscarUsuarioPorEmail(input.email);

    if (usuarioExistente) {
      throw new AppError(
        "EMAIL_JA_CADASTRADO",
        "Ja existe uma conta cadastrada com este e-mail.",
        409,
      );
    }

    const result = await getPool().query<UsuarioAuthRow>(
      `insert into usuarios (nome, email, telefone, sexo, tipo_usuario, senha)
       values ($1, $2, $3, $4, $5, $6)
       returning *`,
      [
        input.nome.trim(),
        input.email.trim().toLowerCase(),
        input.telefone?.trim() || null,
        input.sexo ?? null,
        input.tipoUsuario,
        criarHashSenha(input.senha),
      ],
    );

    return {
      usuario: toUsuarioPublico(result.rows[0]),
    };
  },

  async loginGoogle(input: GoogleLoginInput) {
    const google = await validarGoogleToken(input.idToken);
    const usuarioExistente = await buscarUsuarioPorEmail(google.email);

    if (usuarioExistente) {
      if (google.fotoUrl && !usuarioExistente.url_foto) {
        const atualizado = await getPool().query<UsuarioAuthRow>(
          `
            update usuarios
            set url_foto = $1
            where id = $2
            returning *
          `,
          [google.fotoUrl, usuarioExistente.id],
        );
        return { usuario: toUsuarioPublico(atualizado.rows[0]) };
      }

      return { usuario: toUsuarioPublico(usuarioExistente) };
    }

    return {
      precisaCadastro: true,
      google: {
        email: google.email,
        nome: google.nome,
        urlFoto: google.fotoUrl,
      },
    };
  },

  async cadastrarGoogle(input: GoogleCadastroInput) {
    const google = await validarGoogleToken(input.idToken);
    const usuarioExistente = await buscarUsuarioPorEmail(google.email);

    if (usuarioExistente) {
      return { usuario: toUsuarioPublico(usuarioExistente) };
    }

    const result = await getPool().query<UsuarioAuthRow>(
      `insert into usuarios (nome, email, telefone, sexo, url_foto, tipo_usuario, senha)
       values ($1, $2, $3, $4, $5, $6, $7)
       returning *`,
      [
        input.nome.trim(),
        google.email,
        input.telefone?.trim() || null,
        input.sexo ?? null,
        google.fotoUrl,
        "cuidador",
        "google-auth",
      ],
    );

    return {
      usuario: toUsuarioPublico(result.rows[0]),
    };
  },

  async alterarSenha(input: AlterarSenhaInput) {
    const usuario = await buscarUsuarioPorId(input.usuarioId);

    if (!usuario) {
      throw new AppError(
        "USUARIO_NAO_ENCONTRADO",
        "Usuário não encontrado.",
        404,
      );
    }

    if (usuario.senha === "google-auth") {
      throw new AppError(
        "SENHA_NAO_CONFIGURADA",
        "Esta conta usa login com Google. Cadastre uma senha antes de altera-la.",
        409,
      );
    }

    if (!senhaConfere(input.senhaAtual, usuario.senha)) {
      throw new AppError("SENHA_ATUAL_INVALIDA", "Senha atual incorreta.", 401);
    }

    const result = await getPool().query<UsuarioAuthRow>(
      `
        update usuarios
        set senha = $1, atualizado_em = now()
        where id = $2
        returning *
      `,
      [criarHashSenha(input.novaSenha), input.usuarioId],
    );

    return { usuario: toUsuarioPublico(result.rows[0]) };
  },
};
