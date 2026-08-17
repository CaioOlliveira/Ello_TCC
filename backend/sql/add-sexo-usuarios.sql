-- Armazena o sexo do usuário para adequar os textos de cuidado no aplicativo.
alter table public.usuarios
add column if not exists sexo text;

update public.usuarios
set sexo = case
  when lower(trim(sexo)) in ('f', 'fem', 'feminino', 'mulher') then 'Feminino'
  when lower(trim(sexo)) in ('m', 'masc', 'masculino', 'homem') then 'Masculino'
  when lower(trim(sexo)) in ('outro', 'outra', 'nao binario', 'não binário', 'nao_binario', 'nonbinary') then 'Outro'
  else sexo
end
where sexo is not null;

alter table public.usuarios
drop constraint if exists usuarios_sexo_check;

alter table public.usuarios
add constraint usuarios_sexo_check
check (sexo is null or sexo in ('Feminino', 'Masculino', 'Outro'));
