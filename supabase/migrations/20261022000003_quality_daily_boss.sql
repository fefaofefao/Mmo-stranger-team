-- Qualidade dos monstros (0-100, sorteada no servidor) e estado do Chefe Diário.
alter table public.monsters add column if not exists quality int not null default 0 check (quality between 0 and 100);
alter table public.players  add column if not exists daily jsonb not null default '{}'::jsonb;
