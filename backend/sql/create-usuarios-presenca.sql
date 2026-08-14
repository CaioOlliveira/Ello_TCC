create table if not exists public.usuarios_presenca (
  usuario_id uuid primary key references public.usuarios(id) on delete cascade,
  ultimo_visto_em timestamptz not null default now()
);

create index if not exists idx_usuarios_presenca_ultimo_visto
  on public.usuarios_presenca (ultimo_visto_em desc);
