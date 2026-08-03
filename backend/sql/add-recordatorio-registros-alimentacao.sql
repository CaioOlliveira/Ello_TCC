alter table public.registros_alimentacao
add column if not exists recordatorio text;

comment on column public.registros_alimentacao.recordatorio
is 'Foto da refeicao em data URL, usada como recordatorio visual do cuidado.';
