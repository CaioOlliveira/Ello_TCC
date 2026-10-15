import { describe, expect, it, vi } from "vitest";

const { query, insertRow, updateRow, enviarPushSolicitacaoAcesso } =
  vi.hoisted(() => ({
    query: vi.fn(),
    insertRow: vi.fn(),
    updateRow: vi.fn(),
    enviarPushSolicitacaoAcesso: vi.fn(async () => undefined),
  }));

vi.mock("../src/database/pool.js", () => ({
  getPool: () => ({ query }),
}));
vi.mock("../src/database/simple-crud.js", () => ({
  insertRow,
  updateRow,
}));
vi.mock("../src/database/audit.js", () => ({
  registrarHistorico: async () => undefined,
}));
vi.mock("../src/modules/chat-familia/chat-push.service.js", () => ({
  enviarPushSolicitacaoAcesso,
}));

import { convitesService } from "../src/modules/convites/convites.service.js";

describe("aviso de solicitação de acesso", () => {
  it("avisa apenas os administradores da ficha com o id da solicitação", async () => {
    const idosoId = "11111111-1111-4111-8111-111111111111";
    const solicitanteId = "22222222-2222-4222-8222-222222222222";
    const donoId = "33333333-3333-4333-8333-333333333333";
    const adminId = "44444444-4444-4444-8444-444444444444";
    const solicitacaoId = "55555555-5555-4555-8555-555555555555";
    query.mockImplementation(async (sql: string) => {
      if (sql.includes("from convites")) {
        return {
          rows: [{ id: "convite", idoso_id: idosoId, status: "ativo" }],
        };
      }
      if (sql.includes("select criado_por_id from fichas_idosos")) {
        return { rows: [{ criado_por_id: donoId }] };
      }
      if (sql.includes("select distinct destinatario.usuario_id")) {
        return {
          rows: [donoId, adminId].map((usuario_id) => ({
            usuario_id,
            solicitante_nome: "Caio",
            paciente_nome: "Maria",
          })),
        };
      }
      if (sql.includes("from membros_ficha") && sql.includes("limit 1")) {
        return { rows: [] };
      }
      return { rows: [] };
    });
    insertRow.mockResolvedValue({ id: solicitacaoId });
    updateRow.mockResolvedValue({ id: "convite" });

    await convitesService.aceitar({ codigo: "ABC123", usadoPorId: solicitanteId });

    const inserts = query.mock.calls.filter(([sql]) =>
      String(sql).includes("insert into notificacoes"),
    );
    expect(inserts).toHaveLength(2);
    expect(inserts.map(([, params]) => params[1])).toEqual([donoId, adminId]);
    expect(inserts[0][1][4]).toBe(solicitacaoId);
    expect(enviarPushSolicitacaoAcesso).toHaveBeenCalledTimes(2);
    expect(enviarPushSolicitacaoAcesso).toHaveBeenCalledWith(
      expect.objectContaining({
        destinatarioId: donoId,
        idosoId,
        solicitacaoId,
      }),
    );
  });
});
