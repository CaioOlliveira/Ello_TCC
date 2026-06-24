-- Campos adicionais para o fluxo mobile de insumos.
-- Rode no Supabase SQL Editor antes de usar o cadastro e os alertas pelo app.

alter table public.insumos
add column if not exists foto_url text,
add column if not exists local_armazenamento text,
add column if not exists frequencia_uso text,
add column if not exists dias_alerta_validade integer not null default 7,
add column if not exists ultimo_consumo_em timestamptz not null default now();

alter table public.insumos
drop constraint if exists insumos_dias_alerta_validade_check;

update public.insumos
set frequencia_uso = 'Diario'
where frequencia_uso = 'Eventual'
   or (frequencia_uso is null and consumo_medio_diario > 0);

alter table public.insumos
drop constraint if exists insumos_frequencia_uso_check;

alter table public.insumos
add constraint insumos_dias_alerta_validade_check
check (dias_alerta_validade >= 0 and dias_alerta_validade <= 3650);

alter table public.insumos
add constraint insumos_frequencia_uso_check
check (
  frequencia_uso is null
  or frequencia_uso in ('Diario', 'Semanal', 'Mensal')
);
