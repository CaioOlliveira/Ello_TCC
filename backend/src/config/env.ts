import "dotenv/config";
import { z } from "zod";

const emptyStringToUndefined = (value: unknown) =>
  value === "" ? undefined : value;

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  CORS_ORIGIN: z.string().default("*"),
  DATABASE_URL: z.preprocess(
    emptyStringToUndefined,
    z.string().url().optional(),
  ),
  DIRECT_URL: z.preprocess(emptyStringToUndefined, z.string().url().optional()),
  DEMO_USUARIO_ID: z.preprocess(
    emptyStringToUndefined,
    z.string().uuid().optional(),
  ),
  GEMINI_API_KEY: z.preprocess(emptyStringToUndefined, z.string().optional()),
  GEMINI_MODEL: z
    .preprocess(emptyStringToUndefined, z.string().optional())
    .default("gemini-2.5-flash"),
  AUTH_TOKEN_SECRET: z.preprocess(emptyStringToUndefined, z.string().min(32).optional()),
  AUTH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().max(90).default(30),
  FIREBASE_SERVICE_ACCOUNT_JSON: z.preprocess(
    emptyStringToUndefined,
    z.string().optional(),
  ),
});

export const env = envSchema.parse(process.env);
