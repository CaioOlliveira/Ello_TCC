import request from "supertest";
import { describe, expect, it } from "vitest";

import { app } from "../src/app.js";
import {
  criarMensagemFamiliaSchema,
  listarMensagensFamiliaSchema,
} from "../src/modules/chat-familia/chat-familia.schemas.js";
import {
  criarTokenSessao,
  validarTokenSessao,
} from "../src/common/auth/session-token.js";

const idosoId = "11111111-1111-4111-8111-111111111111";
const usuarioId = "22222222-2222-4222-8222-222222222222";
const contatoId = "33333333-3333-4333-8333-333333333333";

describe("chat familia contracts", () => {
  it("bloqueia conversas sem token antes de consultar dados", async () => {
    const response = await request(app)
      .get(`/api/v1/chat-familia/conversas?idosoId=${idosoId}`)
      .expect(401);

    expect(response.body.codigo).toBe("SESSAO_INVALIDA");
  });

  it("valida cursor paginado e idempotencia do envio", () => {
    const mensagem = criarMensagemFamiliaSchema.parse({
      idosoId,
      destinatarioId: contatoId,
      mensagem: "Oi",
      clienteMensagemId: "mobile-123456",
    });

    expect(mensagem.clienteMensagemId).toBe("mobile-123456");

    expect(() =>
      listarMensagensFamiliaSchema.parse({
        idosoId,
        outroUsuarioId: contatoId,
        antesDe: new Date().toISOString(),
      }),
    ).toThrow("O cursor da conversa esta incompleto.");

    const pagina = listarMensagensFamiliaSchema.parse({
      idosoId,
      outroUsuarioId: contatoId,
      limite: "25",
      antesDe: new Date().toISOString(),
      antesId: usuarioId,
    });

    expect(pagina.limite).toBe(25);
  });

  it("aceita token de sessao valido e rejeita token adulterado", () => {
    const token = criarTokenSessao(usuarioId);

    expect(validarTokenSessao(token)).toBe(usuarioId);
    expect(validarTokenSessao(`${token}x`)).toBeNull();
  });
});
