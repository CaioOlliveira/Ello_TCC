import { z } from "zod";

const dateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Data invalida.");

export const listarGastosQuerySchema = z
  .object({
    idosoId: z.string().uuid("Ficha invalida."),
    inicio: dateSchema.optional(),
    fim: dateSchema.optional(),
  })
  .refine(
    (input) => {
      if (!input.inicio || !input.fim) return true;
      return input.inicio <= input.fim;
    },
    {
      message: "Periodo invalido.",
      path: ["fim"],
    },
  );

export const criarGastoSchema = z.object({
  idosoId: z.string().uuid("Ficha invalida."),
  valor: z.coerce
    .number()
    .positive("Informe um valor maior que zero.")
    .max(999999999, "Valor muito alto."),
  descricao: z.string().trim().min(1, "Descricao e obrigatoria.").max(180),
  fonte: z.string().trim().min(1, "Fonte do dinheiro e obrigatoria.").max(120),
  dataGasto: dateSchema,
});

export type ListarGastosQuery = z.infer<typeof listarGastosQuerySchema>;
export type CriarGastoInput = z.infer<typeof criarGastoSchema>;
