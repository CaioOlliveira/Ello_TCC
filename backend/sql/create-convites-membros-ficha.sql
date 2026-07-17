-- Tabelas de convites e compartilhamento de fichas do app Ello.
-- Rode este script no SQL Editor do Supabase.

create table if not exists public.convites (
  id uuid primary key default gen_random_uuid(),
  idoso_id uuid not null references public.fichas_idosos(id) on delete cascade,
  convidado_por_id uuid not null references public.usuarios(id) on delete cascade,
  codigo text not null,
  funcao_inicial text not null default 'cuidador',
  expira_em timestamptz null,
  usado_por_id uuid null references public.usuarios(id) on delete set null,
  status text not null default 'ativo',
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

alter table public.convites
  add column if not exists idoso_id uuid,
  add column if not exists convidado_por_id uuid,
  add column if not exists codigo text,
  add column if not exists funcao_inicial text,
  add column if not exists expira_em timestamptz,
  add column if not exists usado_por_id uuid,
  add column if not exists status text,
  add column if not exists criado_em timestamptz,
  add column if not exists atualizado_em timestamptz;

update public.convites
set
  funcao_inicial = coalesce(funcao_inicial, 'cuidador'),
  status = coalesce(status, 'ativo'),
  criado_em = coalesce(criado_em, now()),
  atualizado_em = coalesce(atualizado_em, criado_em, now());

alter table public.convites
  alter column funcao_inicial set default 'cuidador',
  alter column funcao_inicial set not null,
  alter column status set default 'ativo',
  alter column status set not null,
  alter column criado_em set default now(),
  alter column criado_em set not null,
  alter column atualizado_em set default now(),
  alter column atualizado_em set not null,
  alter column idoso_id set not null,
  alter column convidado_por_id set not null,
  alter column codigo set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'convites_idoso_id_fkey'
  ) then
    alter table public.convites
      add constraint convites_idoso_id_fkey
      foreign key (idoso_id) references public.fichas_idosos(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'convites_convidado_por_id_fkey'
  ) then
    alter table public.convites
      add constraint convites_convidado_por_id_fkey
      foreign key (convidado_por_id) references public.usuarios(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'convites_usado_por_id_fkey'
  ) then
    alter table public.convites
      add constraint convites_usado_por_id_fkey
      foreign key (usado_por_id) references public.usuarios(id) on delete set null;
  end if;
end $$;

create unique index if not exists idx_convites_codigo on public.convites (codigo);
create index if not exists idx_convites_idoso on public.convites (idoso_id);

create table if not exists public.membros_ficha (
  id uuid primary key default gen_random_uuid(),
  idoso_id uuid not null references public.fichas_idosos(id) on delete cascade,
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  funcao text not null default 'cuidador',
  status text not null default 'ativo',
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

alter table public.membros_ficha
  add column if not exists idoso_id uuid,
  add column if not exists usuario_id uuid,
  add column if not exists funcao text,
  add column if not exists status text,
  add column if not exists criado_em timestamptz,
  add column if not exists atualizado_em timestamptz;

update public.membros_ficha
set
  funcao = coalesce(funcao, 'cuidador'),
  status = coalesce(status, 'ativo'),
  criado_em = coalesce(criado_em, now()),
  atualizado_em = coalesce(atualizado_em, criado_em, now());

alter table public.membros_ficha
  alter column funcao set default 'cuidador',
  alter column funcao set not null,
  alter column status set default 'ativo',
  alter column status set not null,
  alter column criado_em set default now(),
  alter column criado_em set not null,
  alter column atualizado_em set default now(),
  alter column atualizado_em set not null,
  alter column idoso_id set not null,
  alter column usuario_id set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'membros_ficha_idoso_id_fkey'
  ) then
    alter table public.membros_ficha
      add constraint membros_ficha_idoso_id_fkey
      foreign key (idoso_id) references public.fichas_idosos(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'membros_ficha_usuario_id_fkey'
  ) then
    alter table public.membros_ficha
      add constraint membros_ficha_usuario_id_fkey
      foreign key (usuario_id) references public.usuarios(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'membros_ficha_idoso_usuario_unique'
  ) then
    alter table public.membros_ficha
      add constraint membros_ficha_idoso_usuario_unique
      unique (idoso_id, usuario_id);
  end if;
end $$;

create index if not exists idx_membros_ficha_usuario on public.membros_ficha (usuario_id);
create index if not exists idx_membros_ficha_idoso on public.membros_ficha (idoso_id);
