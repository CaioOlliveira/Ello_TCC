# Chat familia e notificacoes

Este documento registra a configuracao operacional do chat familia v2.

## Fluxo atual

- O app autentica chamadas do chat com `Authorization: Bearer <token>` retornado pelo login.
- A lista de conversas vem de `GET /api/v1/chat-familia/conversas` e ja retorna ultima mensagem, horario localizavel pelo app, contador de nao lidas e ordenacao por atividade recente.
- A tela de conversa carrega mensagens paginadas por cursor em `GET /api/v1/chat-familia/mensagens`.
- O envio usa `clienteMensagemId` para idempotencia. Se o app repetir a requisicao, o servidor devolve a mesma mensagem sem duplicar.
- A leitura usa `POST /api/v1/chat-familia/mensagens/lidas` e marca somente mensagens recebidas daquele contato.
- O app mantem um unico controlador de inbox para polling, presenca e badges. A tela aberta da conversa faz apenas o refresh do historico daquela conversa.
- Datas sao gravadas e trafegadas como `timestamptz`/ISO UTC; o app converte para horario local com `toLocal()`.

## Firebase Cloud Messaging

O chat funciona por polling mesmo sem Firebase configurado. Para notificacoes em segundo plano ou com o app fechado, configure:

1. Criar/abrir o projeto Firebase do app Android com package `com.example.ello_mobile`.
2. Adicionar as digitais SHA do certificado usado para assinar o APK. No build local atual, a digital debug registrada e:
   - SHA-1: `74:46:D2:EF:16:07:53:78:44:2E:3F:0C:3D:86:26:62:7C:7A:13:03`
   - SHA-256: `29:06:60:78:EF:90:3C:87:8D:0B:49:1D:AC:EB:5A:D9:A4:50:FE:3A:4C:BF:19:45:97:5F:53:03:E5:37:C6:C3`
3. Baixar `google-services.json` e colocar em `mobile/android/app/google-services.json`. Esse arquivo fica fora do Git.
4. No Railway, configurar:
   - `AUTH_TOKEN_SECRET`: segredo aleatorio com pelo menos 32 caracteres.
   - `AUTH_TOKEN_TTL_DAYS`: normalmente `30`.
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: JSON completo da service account do Firebase em uma linha.
5. Publicar a API. O app registra o token FCM em `POST /api/v1/chat-familia/dispositivos` depois do login.

## Banco

Rode `backend/sql/migrate-chat-familia-v2.sql` no banco de producao. A migration cria/atualiza:

- `mensagens_chat_familia.cliente_mensagem_id`
- indices de cursor, remetente, destinatario e nao lidas
- `dispositivos_push`
- `eventos_push_chat`

## Observacoes

- Usuarios que ja estavam logados antes desta versao precisam entrar novamente uma vez para salvar o token de sessao usado pelo chat.
- Teste real de push em segundo plano depende de `google-services.json`, `FIREBASE_SERVICE_ACCOUNT_JSON` e dois aparelhos/emuladores com contas diferentes.
