-- Produto "Sem anúncios" (não consumível): remove anúncios em tela cheia; o banner continua.
alter table public.players add column if not exists no_ads boolean not null default false;

create or replace function public._wallet(p uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('gold', gold, 'essences', essences, 'diamonds', diamonds, 'no_ads', no_ads) from players where id = p;
$$;
