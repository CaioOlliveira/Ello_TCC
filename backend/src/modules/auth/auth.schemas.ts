import { z } from "zod";

export const loginProvisorioSchema = z.object({
  email: z.string().email().optional(),
});
