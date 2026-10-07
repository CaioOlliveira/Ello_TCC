# Ello API

API REST do Ello, desenvolvida com Node.js, TypeScript e Express. A documentação geral e as instruções completas estão no [README principal](../README.md).

## Configuração

Crie o arquivo de ambiente local:

```bash
cp .env.example .env
```

O arquivo `.env.example` documenta as opções de banco, autenticação, Google Sign-In, Gemini e Firebase. Não versione credenciais reais.

Sem `DATABASE_URL`, parte dos módulos usa dados em memória para facilitar o desenvolvimento. Com a variável configurada, a API acessa o PostgreSQL hospedado no Supabase.

## Execução

```bash
npm ci
npm run dev
```

A API inicia, por padrão, em `http://localhost:3000/api/v1`. O endpoint `GET /api/v1/health` pode ser usado para verificar o serviço.

## Comandos

| Comando         | Descrição                                |
| --------------- | ---------------------------------------- |
| `npm run dev`   | inicia o servidor com recarga automática |
| `npm run lint`  | verifica o padrão do código              |
| `npm test`      | executa os testes automatizados          |
| `npm run build` | compila o TypeScript para `dist/`        |
| `npm start`     | inicia a versão compilada                |

Consulte também o [guia da API para Postman](../docs/api-postman.md).
