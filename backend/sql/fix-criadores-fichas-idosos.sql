-- Restaura o dono original da ficha usando o primeiro historico de criacao.
-- Rode no Supabase SQL Editor se alguma ficha estiver aparecendo como
-- compartilhada para o usuario que criou a ficha.

with criacoes as (
  select distinct on (entidade_id)
    entidade_id::uuid as ficha_id,
    usuario_id
  from public.historico_alteracoes
  where tipo_entidade = 'fichas_idosos'
    and acao = 'criar'
    and usuario_id is not null
    and entidade_id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  order by entidade_id::text, criado_em asc
)
update public.fichas_idosos f
set criado_por_id = c.usuario_id
from criacoes c
where f.id = c.ficha_id
  and f.criado_por_id is distinct from c.usuario_id;
