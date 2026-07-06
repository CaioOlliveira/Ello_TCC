-- Peso usado para estimar a meta diaria de agua do idoso.
-- Dado pessoal sensivel: manter RLS ativa em fichas_idosos.

alter table public.fichas_idosos
add column if not exists peso_kg numeric;
