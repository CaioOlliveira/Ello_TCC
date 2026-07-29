-- Padroniza o sexo informado na ficha para permitir textos no masculino/feminino.
-- Mantem null para preservar fichas antigas sem esse dado.

alter table public.fichas_idosos
add column if not exists sexo text;

update public.fichas_idosos
set sexo = case
  when lower(trim(sexo)) in ('f', 'fem', 'feminino', 'mulher', 'idosa') then 'Feminino'
  when lower(trim(sexo)) in ('m', 'masc', 'masculino', 'homem', 'idoso') then 'Masculino'
  when lower(trim(sexo)) in ('outro', 'outra', 'nao binario', 'não binário', 'nao_binario', 'nonbinary') then 'Outro'
  else sexo
end
where sexo is not null;

alter table public.fichas_idosos
drop constraint if exists fichas_idosos_sexo_check;

alter table public.fichas_idosos
add constraint fichas_idosos_sexo_check
check (sexo is null or sexo in ('Feminino', 'Masculino', 'Outro'));
