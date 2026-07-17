import { z } from "zod";

export const listarHistoricoQuerySchema = z.object({
  idosoId: z.string().uuid("Idoso invalido."),
  tipo: z.enum(["insumos", "alimentacao", "humor"]),
  inicio: z.string().date("Data inicial invalida."),
  fim: z.string().date("Data final invalida."),
  limite: z.coerce.number().int().positive().max(200).default(100),
});

export type ListarHistoricoQuery = z.infer<typeof listarHistoricoQuerySchema>;
