-- Chat familia v2: idempotencia, paginação, leitura e push.
-- Rode uma vez no banco de producao antes, ou junto, da publicacao da API.

create table if not exists mensagens_chat_familia (
  id uuid primary key,
  idoso_id uuid not null references fichas_idosos(id) on delete cascade,
  remetente_id uuid not null references usuarios(id) on delete cascade,
  destinatario_id uuid not null references usuarios(id) on delete cascade,
  mensagem text not null,
  imagem_url text,
  lido_em timestamptz,
  criado_em timestamptz not null default now()
);

alter table mensagens_chat_familia
  add column if not exists cliente_mensagem_id varchar(128) null;

update mensagens_chat_familia
set cliente_mensagem_id = id::text
where cliente_mensagem_id is null;

alter table mensagens_chat_familia
  alter column cliente_mensagem_id set not null;

create unique index if not exists mensagens_chat_familia_cliente_unico_idx
  on mensagens_chat_familia (remetente_id, cliente_mensagem_id);

create index if not exists mensagens_chat_familia_conversa_cursor_idx
  on mensagens_chat_familia (
    idoso_id,
    least(remetente_id, destinatario_id),
    greatest(remetente_id, destinatario_id),
    criado_em desc,
    id desc
  );

create index if not exists mensagens_chat_familia_remetente_idx
  on mensagens_chat_familia (idoso_id, remetente_id, criado_em desc, id desc);

create index if not exists mensagens_chat_familia_destinatario_idx
  on mensagens_chat_familia (idoso_id, destinatario_id, criado_em desc, id desc);

create index if not exists mensagens_chat_familia_nao_lidas_v2_idx
  on mensagens_chat_familia (
    idoso_id,
    destinatario_id,
    remetente_id,
    criado_em desc
  )
  where lido_em is null;

create table if not exists dispositivos_push (
  token text primary key,
  usuario_id uuid not null references usuarios(id) on delete cascade,
  plataforma varchar(16) not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists dispositivos_push_usuario_idx
  on dispositivos_push (usuario_id);

create table if not exists eventos_push_chat (
  id uuid primary key,
  mensagem_id uuid not null unique references mensagens_chat_familia(id) on delete cascade,
  destinatario_id uuid not null references usuarios(id) on delete cascade,
  payload jsonb not null,
  tentativas integer not null default 0,
  proxima_tentativa_em timestamptz not null default now(),
  enviado_em timestamptz null,
  ultimo_erro text null,
  criado_em timestamptz not null default now()
);

create index if not exists eventos_push_chat_pendentes_idx
  on eventos_push_chat (proxima_tentativa_em asc)
  where enviado_em is null;
