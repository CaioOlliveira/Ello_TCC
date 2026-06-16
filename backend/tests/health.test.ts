import request from "supertest";
import { describe, expect, it } from "vitest";

import { app } from "../src/app.js";

describe("API Ello", () => {
  it("retorna status da API", async () => {
    const response = await request(app).get("/api/v1/health").expect(200);

    expect(response.body).toMatchObject({
      status: "ok",
      service: "ello-api",
    });
    expect(response.body.timestamp).toEqual(expect.any(String));
  });

  it("retorna 404 quando idoso nao existe", async () => {
    const response = await request(app)
      .get("/api/v1/idosos/idoso-inexistente")
      .expect(404);

    expect(response.body).toEqual({
      codigo: "IDOSO_NAO_ENCONTRADO",
      mensagem: "Idoso não encontrado.",
    });
  });

  it("valida glicemia com valor invalido", async () => {
    const response = await request(app)
      .post("/api/v1/glicemias")
      .send({
        idosoId: "idoso-1",
        valor: -1,
        contexto: "jejum",
        medidoEm: new Date().toISOString(),
      })
      .expect(400);

    expect(response.body.codigo).toBe("DADOS_INVALIDOS");
    expect(response.body.mensagem).toBe("Existem informações inválidas.");
    expect(response.body.campos.valor).toBe("Valor deve ser positivo.");
  });
});
