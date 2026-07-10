-- Tabelas de chats da IA do app Ello.
-- Rode este script no SQL Editor do Supabase.

create table if not exists public.conversas_ia (
  id uuid primary key,
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  idoso_id uuid null references public.fichas_idosos(id) on delete set null,
  titulo text not null default 'Novo chat',
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

alter table public.conversas_ia
  add column if not exists usuario_id uuid,
  add column if not exists idoso_id uuid,
  add column if not exists titulo text,
  add column if not exists criado_em timestamptz,
  add column if not exists atualizado_em timestamptz;

update public.conversas_ia
set
  titulo = coalesce(titulo, 'Novo chat'),
  criado_em = coalesce(criado_em, now()),
  atualizado_em = coalesce(atualizado_em, criado_em, now());

alter table public.conversas_ia
  alter column titulo set default 'Novo chat',
  alter column titulo set not null,
  alter column criado_em set default now(),
  alter column criado_em set not null,
  alter column atualizado_em set default now(),
  alter column atualizado_em set not null,
  alter column usuario_id set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'conversas_ia_usuario_id_fkey'
  ) then
    alter table public.conversas_ia
      add constraint conversas_ia_usuario_id_fkey
      foreign key (usuario_id)
      references public.usuarios(id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'conversas_ia_idoso_id_fkey'
  ) then
    alter table public.conversas_ia
      add constraint conversas_ia_idoso_id_fkey
      foreign key (idoso_id)
      references public.fichas_idosos(id)
      on delete set null;
  end if;
end $$;

create table if not exists public.mensagens_ia (
  id uuid primary key,
  conversa_id uuid not null references public.conversas_ia(id) on delete cascade,
  remetente text not null check (remetente in ('usuario', 'ia')),
  conteudo text not null,
  criado_em timestamptz not null default now()
);

alter table public.mensagens_ia
  add column if not exists conversa_id uuid,
  add column if not exists remetente text,
  add column if not exists conteudo text,
  add column if not exists criado_em timestamptz;

update public.mensagens_ia
set criado_em = coalesce(criado_em, now());

alter table public.mensagens_ia
  alter column conversa_id set not null,
  alter column remetente set not null,
  alter column conteudo set not null,
  alter column criado_em set default now(),
  alter column criado_em set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'mensagens_ia_conversa_id_fkey'
  ) then
    alter table public.mensagens_ia
      add constraint mensagens_ia_conversa_id_fkey
      foreign key (conversa_id)
      references public.conversas_ia(id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'mensagens_ia_remetente_check'
  ) then
    alter table public.mensagens_ia
      add constraint mensagens_ia_remetente_check
      check (remetente in ('usuario', 'ia'));
  end if;
end $$;

create index if not exists idx_conversas_ia_usuario_atualizado
  on public.conversas_ia (usuario_id, atualizado_em desc);

create index if not exists idx_conversas_ia_idoso
  on public.conversas_ia (idoso_id);

create index if not exists idx_mensagens_ia_conversa_criado
  on public.mensagens_ia (conversa_id, criado_em asc);
