alter table if exists mensagens_ia
  add column if not exists anexos jsonb;

create index if not exists idx_mensagens_ia_conversa_anexos
  on mensagens_ia (conversa_id)
  where anexos is not null;

-- A API usa trava transacional por medicamento + horario_previsto para impedir
-- duplicidade. Se nao houver duplicidades antigas, este indice reforca a regra.
do $$
begin
  if not exists (
    select 1
    from administracoes_medicamentos
    group by medicamento_id, idoso_id, horario_previsto
    having count(*) > 1
  ) then
    create unique index if not exists idx_administracoes_medicamentos_dose_unica
      on administracoes_medicamentos (medicamento_id, idoso_id, horario_previsto);
  end if;
end $$;
