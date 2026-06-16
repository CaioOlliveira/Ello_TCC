import { app } from "./app.js";
import { env } from "./config/env.js";

try {
  app.listen(env.PORT, () => {
    console.log(`Ello API executando na porta ${env.PORT}`);
  });
} catch (error) {
  console.error("Erro ao iniciar a API.", error);
  process.exit(1);
}
