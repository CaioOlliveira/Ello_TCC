# Arquitetura

O Ello usa uma arquitetura simples e expansivel:

```text
Flutter
  -> requisicoes HTTP com Dio
  -> API Node.js com Express
  -> PostgreSQL no Supabase via DATABASE_URL
```

O aplicativo Flutter centraliza tema, rotas e providers na pasta `lib/app`. As funcionalidades ficam separadas em `lib/features`, com espaco para camadas `data`, `domain` e `presentation`.

A API Node.js usa Express com rotas modulares, validacao com Zod e tratamento centralizado de erros. Quando `DATABASE_URL` existe, os services acessam o PostgreSQL do Supabase com `pg`. Quando a variavel nao existe, alguns modulos mantem fallback em memoria para facilitar testes e desenvolvimento inicial.

Nao ha Prisma, ORM ou autenticacao real nesta fase.

## Execucao

Backend:

```bash
cd backend
npm install
npm run dev
```

Flutter:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

`10.0.2.2` e usado pelo emulador Android para acessar o `localhost` do computador. Em dispositivo fisico, use o IP local do computador. Em producao, use uma URL HTTPS.
