-- Ajuste da tabela de registros de humor para a tela mobile.
-- Rode no Supabase SQL Editor se sua tabela ainda usa registrado_em/possivel_motivo.

alter table public.registros_humor
add column if not exists horario_regi time,
add column if not exists data_humor date;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'registros_humor'
      and column_name = 'registrado_em'
  ) then
    update public.registros_humor
    set
      horario_regi = coalesce(horario_regi, registrado_em::time),
      data_humor = coalesce(data_humor, registrado_em::date)
    where registrado_em is not null;
  end if;
end $$;

alter table public.registros_humor
alter column horario_regi set not null,
alter column data_humor set not null;

alter table public.registros_humor
drop column if exists registrado_em,
drop column if exists possivel_motivo;

drop index if exists idx_registros_humor_data_horario;
create index idx_registros_humor_data_horario
on public.registros_humor(idoso_id, data_humor desc, horario_regi desc);
