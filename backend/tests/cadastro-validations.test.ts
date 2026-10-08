import { describe, expect, it } from "vitest";

import { criarIdosoSchema } from "../src/modules/idosos/idosos.schemas.js";
import {
  atualizarMedicamentoSchema,
  criarMedicamentoSchema,
} from "../src/modules/medicamentos/medicamentos.schemas.js";

describe("validacoes de cadastro", () => {
  it("aceita nome completo com letras e acentos", () => {
    const result = criarIdosoSchema.safeParse({
      nomeCompleto: "Mônica Aparecida da Silva",
    });

    expect(result.success).toBe(true);
  });

  it.each(["Maria 123", "João @ Silva", "Maria"])(
    "rejeita nome inválido: %s",
    (nomeCompleto) => {
      const result = criarIdosoSchema.safeParse({ nomeCompleto });

      expect(result.success).toBe(false);
    },
  );

  it("rejeita medicamento cuja data de término antecede o início", () => {
    const result = criarMedicamentoSchema.safeParse({
      idosoId: "00000000-0000-4000-8000-000000000001",
      nome: "Medicamento de teste",
      dataInicio: "2099-01-01",
      dataFim: "2026-01-01",
    });

    expect(result.success).toBe(false);
    expect(result.error?.issues[0]?.path).toEqual(["dataFim"]);
  });

  it("aplica a validação de datas também na edição", () => {
    const result = atualizarMedicamentoSchema.safeParse({
      dataInicio: "2099-01-01",
      dataFim: "2026-01-01",
    });

    expect(result.success).toBe(false);
  });
});
