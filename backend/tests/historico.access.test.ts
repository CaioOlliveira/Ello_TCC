import request from "supertest";
import { describe, expect, it, vi } from "vitest";

vi.mock("../src/database/pool.js", () => ({
  isDatabaseEnabled: true,
  getPool: () => ({ query: async () => ({ rowCount: 0, rows: [] }) }),
}));

import { app } from "../src/app.js";
import { criarTokenSessao } from "../src/common/auth/session-token.js";

const query =
  "/api/v1/historico?tipo=agenda&idosoId=11111111-1111-4111-8111-111111111111&inicio=2026-10-14&fim=2026-10-14";

describe("acesso ao histórico", () => {
  it("exige sessão", async () => {
    const response = await request(app).get(query);
    expect(response.status).toBe(401);
  });

  it("não mostra o histórico de outra ficha", async () => {
    const token = criarTokenSessao("22222222-2222-4222-8222-222222222222");
    const response = await request(app)
      .get(query)
      .set("Authorization", `Bearer ${token}`);
    expect(response.status).toBe(403);
    expect(response.body.codigo).toBe("ACESSO_FICHA_NEGADO");
  });
});
