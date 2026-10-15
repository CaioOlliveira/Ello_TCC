-- Corrige apenas as cinco ações da agenda mostradas no teste de 14/10/2026.
-- A API antiga gravou o usuário padrão (Wellington) em vez da sessão de Caio.
-- A publicação da API que usa o usuário autenticado evita novas atribuições erradas.
begin;

do $$
declare
  alterados integer;
begin
  update historico_alteracoes
  set usuario_id = '884dd2e8-b1a5-4754-be62-8b09c1b14223'
  where id in (
    '169baaad-517c-4067-9c17-7e7210a9366b',
    '3d101983-4f8d-4ed6-8271-37fee47a350f',
    '3677b720-e559-4864-ab4b-2d19621bf7ee',
    'dfe08015-a60f-45a7-8cb9-b1306e01fdfd',
    'ca0fe89e-7624-4c3f-8a8b-9cb6c2996c8d'
  )
    and tipo_entidade = 'tarefas'
    and acao = 'atualizar_ocorrencia'
    and usuario_id = '6719cda4-a567-4be8-af49-00331ce2483e'
    and criado_em >= timestamptz '2026-10-15 01:51:00+00'
    and criado_em < timestamptz '2026-10-15 01:53:00+00';

  get diagnostics alterados = row_count;
  if alterados <> 5 then
    raise exception 'Esperadas 5 ações da agenda; encontradas %', alterados;
  end if;
end $$;

commit;
