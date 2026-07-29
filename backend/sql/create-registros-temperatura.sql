-- Tabela de registros de temperatura corporal do idoso.
-- Rode este script no SQL Editor do Supabase.

create table if not exists public.registros_temperatura (
  id uuid primary key default gen_random_uuid(),
  idoso_id uuid not null references public.fichas_idosos(id) on delete cascade,
  temperatura_celsius numeric not null check (
    temperatura_celsius >= 25 and temperatura_celsius <= 45
  ),
  medido_em timestamptz not null default now(),
  observacoes text,
  registrado_por_id uuid references public.usuarios(id),
  criado_em timestamptz not null default now()
);

create index if not exists idx_registros_temperatura_idoso_medido
  on public.registros_temperatura (idoso_id, medido_em desc);
