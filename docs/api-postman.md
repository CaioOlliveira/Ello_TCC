# API Ello - Guia Rapido para Postman

Base URL local:

```text
http://localhost:3000/api/v1
```

Idoso de teste existente no Supabase:

```text
22222222-2222-2222-2222-222222222222
```

## Saude

- `GET /health`

## Usuarios

- `GET /usuarios`
- `POST /usuarios`
- `GET /usuarios/:id`
- `PATCH /usuarios/:id`
- `DELETE /usuarios/:id`

```json
{
  "nome": "Cuidador Teste",
  "email": "cuidador.teste@example.com",
  "telefone": "11999999999",
  "tipoUsuario": "cuidador"
}
```

## Idosos

- `GET /idosos`
- `POST /idosos`
- `GET /idosos/:idosoId`
- `PATCH /idosos/:id`
- `DELETE /idosos/:id`

```json
{
  "nomeCompleto": "Maria Aparecida Santos",
  "dataNascimento": "1948-06-10",
  "observacoesSaude": "Hipertensão e diabetes controlados.",
  "limitacoes": "Dificuldade para caminhar longas distâncias."
}
```

## Dashboard

- `GET /dashboard/idosos/:idosoId`

## Membros e Convites

- `GET /membros?idosoId=:idosoId`
- `POST /membros`
- `PATCH /membros/:id`
- `DELETE /membros/:id`
- `GET /convites`
- `POST /convites`
- `POST /convites/aceitar`
- `POST /convites/:id/revogar`

```json
{
  "idosoId": "22222222-2222-2222-2222-222222222222",
  "funcaoInicial": "cuidador",
  "status": "ativo"
}
```

## Glicemia

- `GET /glicemias?idosoId=:idosoId`
- `POST /glicemias`
- `GET /glicemias/:id`
- `PATCH /glicemias/:id`
- `DELETE /glicemias/:id`

```json
{
  "idosoId": "22222222-2222-2222-2222-222222222222",
  "valor": 112,
  "contexto": "jejum",
  "medidoEm": "2026-06-16T12:00:00.000Z",
  "sintomas": "Sem sintomas",
  "observacoes": "Registro de teste"
}
```

## Alimentacao

- `GET /refeicoes?idosoId=:idosoId`
- `POST /refeicoes`
- `GET /refeicoes/:id`
- `DELETE /refeicoes/:id`

```json
{
  "idosoId": "22222222-2222-2222-2222-222222222222",
  "tipoRefeicao": "almoço",
  "alimentos": ["Arroz", "Feijão", "Frango"],
  "aceitacao": "Comeu bem",
  "registradoEm": "2026-06-16T15:00:00.000Z",
  "observacoes": "Sem intercorrências"
}
```

## Medicamentos

- `GET /medicamentos?idosoId=:idosoId`
- `POST /medicamentos`
- `GET /medicamentos/:id`
- `PATCH /medicamentos/:id`
- `DELETE /medicamentos/:id`
- `GET /medicamentos/:id/horarios`
- `POST /medicamentos/:id/horarios`
- `POST /medicamentos/:id/administracoes`

```json
{
  "idosoId": "22222222-2222-2222-2222-222222222222",
  "nome": "Metformina",
  "dosagem": "500mg",
  "formato": "comprimido",
  "quantidadeEstoque": 30,
  "unidadeEstoque": "comprimidos",
  "alertaEstoqueBaixo": 8
}
```

## Agenda

- `GET /agenda?idosoId=:idosoId`
- `POST /agenda`
- `GET /agenda/:id`
- `PATCH /agenda/:id`
- `DELETE /agenda/:id`

```json
{
  "idosoId": "22222222-2222-2222-2222-222222222222",
  "titulo": "Consulta cardiologista",
  "tipoEvento": "consulta",
  "inicioEm": "2026-06-20T13:00:00.000Z",
  "local": "Clínica Central",
  "status": "agendado"
}
```

## Equipamentos

- `GET /equipamentos?idosoId=:idosoId`
- `POST /equipamentos`
- `GET /equipamentos/:id`
- `PATCH /equipamentos/:id`
- `DELETE /equipamentos/:id`
- `POST /equipamentos/:id/manutencoes`

## Insumos

- `GET /insumos?idosoId=:idosoId`
- `POST /insumos`
- `GET /insumos/:id`
- `PATCH /insumos/:id`
- `DELETE /insumos/:id`
- `GET /insumos/:id/movimentacoes`
- `POST /insumos/:id/movimentacoes`

```json
{
  "idosoId": "22222222-2222-2222-2222-222222222222",
  "nome": "Tiras reagentes",
  "tipoUnidade": "unidade",
  "quantidadeUnidades": 25,
  "alertaMinimoUnidades": 10,
  "consumoMedioDiario": 3
}
```

Movimentacao:

```json
{
  "tipo": "entrada",
  "quantidade": 20,
  "motivo": "Compra",
  "observacoes": "Teste via Postman"
}
```

## Registros Extras

- `GET /registros/hidratacoes?idosoId=:idosoId`
- `POST /registros/hidratacoes`
- `GET /registros/humores?idosoId=:idosoId`
- `POST /registros/humores`
- `GET /registros/sonos?idosoId=:idosoId`
- `POST /registros/sonos`
- `GET /registros/oxigenacoes?idosoId=:idosoId`
- `POST /registros/oxigenacoes`
- `GET /registros/pressoes?idosoId=:idosoId`
- `POST /registros/pressoes`

## Relatorios e Notificacoes

- `GET /relatorios?idosoId=:idosoId`
- `POST /relatorios`
- `GET /notificacoes?usuarioId=:usuarioId`
- `POST /notificacoes`
- `POST /notificacoes/:id/lida`

Todas as respostas seguem:

```json
{
  "dados": {}
}
```

ou listas:

```json
{
  "dados": [],
  "meta": {
    "total": 0
  }
}
```
