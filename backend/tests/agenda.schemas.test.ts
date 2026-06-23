import { describe, expect, it } from "vitest";

import { atualizarEventoSchema } from "../src/modules/agenda/agenda.schemas.js";

describe("agenda schemas", () => {
  it("nao injeta tags nem lembrete em atualizacao parcial de status", () => {
    const input = atualizarEventoSchema.parse({ status: "concluido" });

    expect(input).toEqual({ status: "concluido" });
    expect(Object.hasOwn(input, "tags")).toBe(false);
    expect(Object.hasOwn(input, "ativarLembrete")).toBe(false);
  });

  it("normaliza tags quando a atualizacao envia tipo de evento", () => {
    const input = atualizarEventoSchema.parse({ tipoEvento: "Exame" });

    expect(input).toEqual({ tags: ["Exame"] });
  });
});
