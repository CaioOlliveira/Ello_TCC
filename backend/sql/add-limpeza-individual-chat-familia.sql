-- Salva a limpeza de conversa por usuario. A pessoa que limpa deixa de ver
-- mensagens anteriores, sem remover o historico da outra pessoa.
create table if not exists public.conversas_chat_familia_limpas (
  idoso_id uuid not null references public.fichas_idosos(id) on delete cascade,
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  outro_usuario_id uuid not null references public.usuarios(id) on delete cascade,
  limpo_em timestamptz not null default now(),
  primary key (idoso_id, usuario_id, outro_usuario_id)
);

create index if not exists conversas_chat_familia_limpas_usuario_idx
  on public.conversas_chat_familia_limpas (
    usuario_id,
    idoso_id,
    outro_usuario_id
  );
