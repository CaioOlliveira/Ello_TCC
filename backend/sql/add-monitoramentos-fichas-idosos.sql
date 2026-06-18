alter table public.fichas_idosos
add column if not exists monitoramentos text[] not null
default array[
  'Medicacoes',
  'Humor',
  'Agenda',
  'Alimentacao',
  'Equipamentos',
  'Insumos',
  'Glicemia'
]::text[];
