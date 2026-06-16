# Ello API

API Node.js com TypeScript e Express para o projeto Ello.

## Configuracao

Copie `.env.example` para `.env` e preencha a senha do banco nas URLs do Supabase:

```env
PORT=3000
NODE_ENV=development
CORS_ORIGIN=*
DATABASE_URL=postgresql://postgres.gsjiteadtvhlkuexeyvk:SUA_SENHA@aws-1-us-east-2.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.gsjiteadtvhlkuexeyvk:SUA_SENHA@aws-1-us-east-2.pooler.supabase.com:5432/postgres
DEMO_USUARIO_ID=
```

`DATABASE_URL` usa o pooler em modo transacao e e usada pela API. `DIRECT_URL` fica documentada para uso futuro em migracoes.

Como ainda nao existe autenticacao real, registros que exigem `registrado_por_id` usam esta ordem:

1. `registradoPorId` enviado no corpo da requisicao.
2. `DEMO_USUARIO_ID` no `.env`.
3. Primeiro usuario encontrado na tabela `usuarios`.

Se `DATABASE_URL` nao for configurada, a API continua usando dados ficticios em memoria.

## Execucao

```bash
npm install
npm run dev
```

Rotas usam o prefixo `/api/v1`.
