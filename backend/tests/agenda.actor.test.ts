import request from "supertest";
import { describe, expect, it, vi } from "vitest";

const { atualizarOcorrencia } = vi.hoisted(() => ({
  atualizarOcorrencia: vi.fn(async () => ({ id: "tarefa" })),
}));

vi.mock("../src/modules/agenda/agenda.service.js", () => ({
  agendaService: {
    buscarPorId: async () => ({ idoso_id: "ficha" }),
    atualizarOcorrencia,
  },
}));
vi.mock("../src/common/auth/ficha-access.js", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../src/common/auth/ficha-access.js")>()),
  validarAcessoFicha: async () => undefined,
}));

import { app } from "../src/app.js";
import { criarTokenSessao } from "../src/common/auth/session-token.js";

describe("autoria das ocorrências da agenda", () => {
  it("usa o usuário da sessão ao concluir um compromisso", async () => {
    const usuarioId = "884dd2e8-b1a5-4754-be62-8b09c1b14223";
    const response = await request(app)
      .patch("/api/v1/agenda/c4e12d1c-c921-400b-8cdf-509f04fafa13/ocorrencias")
      .set("Authorization", `Bearer ${criarTokenSessao(usuarioId)}`)
      .send({ dataOcorrencia: "2026-10-14", status: "concluido" });

    expect(response.status).toBe(200);
    expect(atualizarOcorrencia).toHaveBeenCalledWith(
      "c4e12d1c-c921-400b-8cdf-509f04fafa13",
      { dataOcorrencia: "2026-10-14", status: "concluido" },
      usuarioId,
    );
  });
});
