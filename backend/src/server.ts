import { app } from "./app.js";
import { env } from "./config/env.js";
import { ensurePerformanceIndexes } from "./database/performance-indexes.js";
import { despacharPushsChatPendentes } from "./modules/chat-familia/chat-push.service.js";

try {
  app.listen(env.PORT, () => {
    console.log(`Ello API executando na porta ${env.PORT}`);
    void ensurePerformanceIndexes();
    void despacharPushsChatPendentes();
    const pushTimer = setInterval(() => {
      void despacharPushsChatPendentes();
    }, 30_000);
    pushTimer.unref();
  });
} catch (error) {
  console.error("Erro ao iniciar a API.", error);
  process.exit(1);
}
