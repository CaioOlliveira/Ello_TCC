import { createHmac, timingSafeEqual } from "node:crypto";

import { env } from "../../config/env.js";

type SessionPayload = {
  sub: string;
  iat: number;
  exp: number;
};

const encode = (value: unknown) =>
  Buffer.from(JSON.stringify(value)).toString("base64url");

const secret = () => {
  if (env.AUTH_TOKEN_SECRET) return env.AUTH_TOKEN_SECRET;

  // Mantem as sessoes funcionando na instalacao existente. Em producao a
  // variavel AUTH_TOKEN_SECRET deve ser definida explicitamente no Railway.
  return `ello-session:${env.DATABASE_URL ?? "development-only-secret"}`;
};

const signature = (value: string) =>
  createHmac("sha256", secret()).update(value).digest("base64url");

export const criarTokenSessao = (usuarioId: string) => {
  const agora = Math.floor(Date.now() / 1000);
  const payload: SessionPayload = {
    sub: usuarioId,
    iat: agora,
    exp: agora + env.AUTH_TOKEN_TTL_DAYS * 24 * 60 * 60,
  };
  const header = encode({ alg: "HS256", typ: "JWT" });
  const body = encode(payload);
  const unsignedToken = `${header}.${body}`;
  return `${unsignedToken}.${signature(unsignedToken)}`;
};

export const validarTokenSessao = (token: string): string | null => {
  const [header, body, receivedSignature, ...extra] = token.split(".");
  if (!header || !body || !receivedSignature || extra.length > 0) return null;

  const expectedSignature = signature(`${header}.${body}`);
  const expected = Buffer.from(expectedSignature);
  const received = Buffer.from(receivedSignature);
  if (
    expected.length !== received.length ||
    !timingSafeEqual(expected, received)
  ) {
    return null;
  }

  try {
    const payload = JSON.parse(
      Buffer.from(body, "base64url").toString("utf8"),
    ) as Partial<SessionPayload>;
    if (
      typeof payload.sub !== "string" ||
      payload.sub.length === 0 ||
      typeof payload.exp !== "number" ||
      payload.exp <= Math.floor(Date.now() / 1000)
    ) {
      return null;
    }
    return payload.sub;
  } catch {
    return null;
  }
};
