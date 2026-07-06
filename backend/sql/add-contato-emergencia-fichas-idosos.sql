-- Campos de contato de emergencia da ficha do idoso.
-- Rode no Supabase SQL Editor antes de salvar/editar esses dados pelo app.

alter table public.fichas_idosos
add column if not exists contato_emergencia_nome text,
add column if not exists contato_emergencia_telefone text,
add column if not exists contato_emergencia_parentesco text,
add column if not exists observacoes_emergencia text;
