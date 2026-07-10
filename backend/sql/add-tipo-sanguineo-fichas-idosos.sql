-- Adiciona tipo sanguineo na ficha do idoso.
-- Rode no Supabase SQL Editor antes de salvar novas fichas com esse campo.

alter table public.fichas_idosos
add column if not exists tipo_sanguineo text;

alter table public.fichas_idosos
drop constraint if exists fichas_idosos_tipo_sanguineo_check;

alter table public.fichas_idosos
add constraint fichas_idosos_tipo_sanguineo_check
check (
  tipo_sanguineo is null
  or tipo_sanguineo in ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
);
