-- Campos para o fluxo mobile de alimentacao.
-- Rode no Supabase SQL Editor antes de usar a nova tela.

alter table public.registros_alimentacao
add column if not exists data_consumo date,
add column if not exists hora_consumo time,
add column if not exists alimentos_consumidos jsonb default '[]'::jsonb,
add column if not exists recordatorio text,
add column if not exists concluida_em timestamptz;

update public.registros_alimentacao
set
  data_consumo = coalesce(data_consumo, alimentou_em::date),
  hora_consumo = coalesce(hora_consumo, alimentou_em::time)
where alimentou_em is not null;

create table if not exists public.dicas_alimentacao (
  id uuid primary key default gen_random_uuid(),
  texto text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

alter table public.dicas_alimentacao enable row level security;

drop policy if exists dicas_alimentacao_select_ativas
on public.dicas_alimentacao;

create policy dicas_alimentacao_select_ativas
on public.dicas_alimentacao
for select
to authenticated
using (ativo = true);

insert into public.dicas_alimentacao (texto)
select 'Refeicoes nutritivas fazem toda a diferenca.'
where not exists (select 1 from public.dicas_alimentacao);

create index if not exists idx_registros_alimentacao_data_hora
on public.registros_alimentacao(idoso_id, data_consumo desc, hora_consumo desc);
