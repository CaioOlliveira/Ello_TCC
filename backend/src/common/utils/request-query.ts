import { z } from "zod";

export const idParamSchema = z.object({
  id: z.string().uuid("ID inválido."),
});

export const paginationSchema = z.object({
  pagina: z.coerce.number().int().positive().default(1),
  limite: z.coerce.number().int().positive().max(100).default(20),
});

export const getPagination = (query: unknown) => {
  const { pagina, limite } = paginationSchema.parse(query);
  return {
    pagina,
    limite,
    offset: (pagina - 1) * limite,
  };
};
