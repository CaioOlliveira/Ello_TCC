create table if not exists public.solicitacoes_cancelamento_medicamento (
  id uuid primary key default gen_random_uuid(),
  idoso_id uuid not null references public.fichas_idosos(id) on delete cascade,
  medicamento_id uuid not null references public.medicamentos(id) on delete cascade,
  administracao_id uuid not null,
  solicitante_id uuid not null references public.usuarios(id) on delete cascade,
  responsavel_id uuid not null references public.usuarios(id) on delete cascade,
  status varchar(16) not null default 'pendente'
    check (status in ('pendente', 'aprovada', 'recusada')),
  respondido_por_id uuid references public.usuarios(id) on delete set null,
  criado_em timestamptz not null default now(),
  respondido_em timestamptz
);

create unique index if not exists solicitacao_cancelamento_dose_pendente_idx
  on public.solicitacoes_cancelamento_medicamento (administracao_id)
  where status = 'pendente';

create index if not exists solicitacoes_cancelamento_responsavel_idx
  on public.solicitacoes_cancelamento_medicamento (
    responsavel_id,
    idoso_id,
    status,
    criado_em desc
  );
