-- Passe VIP (não consumível): recompensas dos anúncios premiados sem assistir o vídeo; o banner continua.
alter table public.players add column if not exists vip boolean not null default false;

create or replace function public._wallet(p uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('gold', gold, 'essences', essences, 'diamonds', diamonds, 'vip', vip) from players where id = p;
$$;
