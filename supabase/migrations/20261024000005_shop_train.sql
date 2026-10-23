-- Loja rotativa (estado por jogador) e treino de monstros com ouro
alter table public.players  add column if not exists shop jsonb not null default '{}'::jsonb;
alter table public.monsters add column if not exists train int not null default 0;
