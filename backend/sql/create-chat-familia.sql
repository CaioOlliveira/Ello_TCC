create table if not exists mensagens_chat_familia (
  id uuid primary key,
  idoso_id uuid not null references fichas_idosos(id) on delete cascade,
  remetente_id uuid not null references usuarios(id) on delete cascade,
  destinatario_id uuid not null references usuarios(id) on delete cascade,
  conteudo text not null default '',
  anexo jsonb null,
  criado_em timestamptz not null default now(),
  lido_em timestamptz null
);

alter table mensagens_chat_familia
  add column if not exists lido_em timestamptz null;

create index if not exists mensagens_chat_familia_conversa_idx
  on mensagens_chat_familia (
    idoso_id,
    least(remetente_id, destinatario_id),
    greatest(remetente_id, destinatario_id),
    criado_em
  );

create index if not exists mensagens_chat_familia_nao_lidas_idx
  on mensagens_chat_familia (idoso_id, destinatario_id, criado_em desc)
  where lido_em is null;
