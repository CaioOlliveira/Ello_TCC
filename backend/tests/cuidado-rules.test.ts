import { describe, expect, it } from "vitest";

import {
  calculateAge,
  formatLocalDate,
  localDayRange,
  parseLocalDate,
} from "../src/common/utils/date-utils.js";
import { criarIdosoSchema } from "../src/modules/idosos/idosos.schemas.js";
import { criarGlicemiaSchema } from "../src/modules/glicemia/glicemia.schemas.js";

describe("regras de dados do cuidado", () => {
  it("calcula idade antes e depois do aniversario", () => {
    const birthDate = new Date(1950, 6, 30);

    expect(calculateAge(birthDate, new Date(2026, 6, 29))).toBe(75);
    expect(calculateAge(birthDate, new Date(2026, 6, 30))).toBe(76);
  });

  it("aceita somente tipos sanguineos padronizados", () => {
    const base = {
      nomeCompleto: "Maria Aparecida",
      tipoSanguineo: "AB+",
    };

    expect(criarIdosoSchema.safeParse(base).success).toBe(true);
    expect(
      criarIdosoSchema.safeParse({ ...base, tipoSanguineo: "A positivo" })
        .success,
    ).toBe(false);
  });

  it("normaliza sexo para flexionar textos do idoso ou da idosa", () => {
    const feminino = criarIdosoSchema.parse({
      nomeCompleto: "Maria Aparecida",
      sexo: "idosa",
    });
    const masculino = criarIdosoSchema.parse({
      nomeCompleto: "Joao Pedro",
      sexo: "M",
    });

    expect(feminino.sexo).toBe("Feminino");
    expect(masculino.sexo).toBe("Masculino");
    expect(
      criarIdosoSchema.safeParse({
        nomeCompleto: "Pessoa Teste",
        sexo: "desconhecido",
      }).success,
    ).toBe(false);
  });

  it("mantem a data local selecionada sem depender de toISOString", () => {
    const parsed = parseLocalDate("2026-02-01");
    const range = localDayRange(parsed);

    expect(formatLocalDate(parsed)).toBe("2026-02-01");
    expect(range.endExclusive.getTime()).toBeGreaterThan(range.start.getTime());
  });

  it("bloqueia medicao futura", () => {
    const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    const result = criarGlicemiaSchema.safeParse({
      idosoId: "idoso-1",
      valor: 100,
      contexto: "jejum",
      medidoEm: future,
    });

    expect(result.success).toBe(false);
  });
});
