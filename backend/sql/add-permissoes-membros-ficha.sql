-- Permissoes granulares e administradores para o compartilhamento de fichas.
-- Rode este script no SQL Editor do Supabase.

alter table public.membros_ficha
  add column if not exists e_administrador boolean not null default false,
  add column if not exists permissoes jsonb not null default '{}'::jsonb;

alter table public.membros_ficha
  alter column funcao drop not null;

create index if not exists idx_membros_ficha_idoso_status
  on public.membros_ficha (idoso_id, status);
