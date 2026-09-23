-- Registros financeiros da ficha. Guarda apenas gastos, sem entradas/ganhos.
-- LGPD: os dados ficam vinculados a uma ficha e so o responsavel deve acessar.
create table if not exists public.gastos_ficha (
  id uuid primary key default gen_random_uuid(),
  idoso_id uuid not null references public.fichas_idosos(id) on delete cascade,
  valor numeric(12, 2) not null check (valor > 0),
  descricao text not null,
  fonte text not null,
  data_gasto date not null default current_date,
  criado_por_id uuid not null references public.usuarios(id) on delete restrict,
  criado_em timestamptz not null default now()
);

create index if not exists idx_gastos_ficha_periodo
  on public.gastos_ficha (idoso_id, data_gasto desc, criado_em desc);

alter table public.gastos_ficha enable row level security;

drop policy if exists gastos_ficha_responsavel_select
on public.gastos_ficha;

create policy gastos_ficha_responsavel_select
on public.gastos_ficha
for select
to authenticated
using (
  exists (
    select 1
    from public.fichas_idosos f
    where f.id = gastos_ficha.idoso_id
      and f.criado_por_id = auth.uid()
  )
);

drop policy if exists gastos_ficha_responsavel_insert
on public.gastos_ficha;

create policy gastos_ficha_responsavel_insert
on public.gastos_ficha
for insert
to authenticated
with check (
  criado_por_id = auth.uid()
  and exists (
    select 1
    from public.fichas_idosos f
    where f.id = gastos_ficha.idoso_id
      and f.criado_por_id = auth.uid()
  )
);

drop policy if exists gastos_ficha_responsavel_update
on public.gastos_ficha;

create policy gastos_ficha_responsavel_update
on public.gastos_ficha
for update
to authenticated
using (
  exists (
    select 1
    from public.fichas_idosos f
    where f.id = gastos_ficha.idoso_id
      and f.criado_por_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.fichas_idosos f
    where f.id = gastos_ficha.idoso_id
      and f.criado_por_id = auth.uid()
  )
);

drop policy if exists gastos_ficha_responsavel_delete
on public.gastos_ficha;

create policy gastos_ficha_responsavel_delete
on public.gastos_ficha
for delete
to authenticated
using (
  exists (
    select 1
    from public.fichas_idosos f
    where f.id = gastos_ficha.idoso_id
      and f.criado_por_id = auth.uid()
  )
);
