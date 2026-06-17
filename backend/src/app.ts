import cors from "cors";
import express from "express";
import helmet from "helmet";
import morgan from "morgan";

import { env } from "./config/env.js";
import { errorHandler } from "./common/middlewares/error-handler.js";
import { notFound } from "./common/middlewares/not-found.js";
import { routes } from "./routes/index.js";

export const app = express();

app.use(express.json({ limit: "2mb" }));
app.use(cors({ origin: env.CORS_ORIGIN === "*" ? true : env.CORS_ORIGIN }));
app.use(helmet());
app.use(morgan(env.NODE_ENV === "test" ? "tiny" : "dev"));

app.use("/api/v1", routes);
app.use(notFound);
app.use(errorHandler);
