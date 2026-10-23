-- =====================================================================
-- Diamantes (moeda de dinheiro real), bônus temporários e monstros no Market (só por diamantes).
-- =====================================================================

alter table public.players add column if not exists diamonds  bigint not null default 0 check (diamonds >= 0);
alter table public.players add column if not exists purchases int    not null default 0;
alter table public.players add column if not exists boosts    jsonb  not null default '{}'::jsonb;

-- compras com dinheiro real já creditadas (o token do Google Play só vale uma vez)
create table if not exists public.iap_purchases (
  token       text primary key,
  owner       uuid not null references public.players(id) on delete cascade,
  product     text not null,
  diamonds    int not null,
  created_at  timestamptz not null default now()
);
alter table public.iap_purchases enable row level security;
create policy "iap: leitura própria" on public.iap_purchases for select using (owner = auth.uid());

-- monstro listado no Market fica sem dono até ser vendido/cancelado
alter table public.monsters alter column owner drop not null;

alter table public.market_listings drop constraint if exists market_listings_kind_check;
alter table public.market_listings add constraint market_listings_kind_check check (kind in ('item', 'essence', 'monster'));
alter table public.market_listings add column if not exists currency   text not null default 'gold' check (currency in ('gold', 'diamonds'));
alter table public.market_listings add column if not exists monster_id text references public.monsters(server_id);
alter table public.market_listings add column if not exists monster    jsonb;
create unique index if not exists market_monster_unique on public.market_listings(monster_id) where monster_id is not null;

create or replace function public._wallet(p uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('gold', gold, 'essences', essences, 'diamonds', diamonds) from players where id = p;
$$;

-- listar monstro (só por diamantes; nível limitado ao validado + 10) --------------
create or replace function public.market_list_monster(p_server_id text, p_level int, p_price bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_m monsters%rowtype;
  v_name text;
  v_vl int;
  v_count int;
  v_snap jsonb;
  v_listing market_listings%rowtype;
begin
  if me is null then raise exception 'não autenticado'; end if;
  if p_price < 10 or p_price > 1000000 then
    return jsonb_build_object('ok', false, 'error', 'Preço inválido');
  end if;
  select name, validated_level into v_name, v_vl from players where id = me for update;
  select count(*) into v_count from market_listings where seller = me;
  if v_count >= _market_cfg('max_listings') then
    return jsonb_build_object('ok', false, 'error', 'Limite de listagens atingido');
  end if;
  select * into v_m from monsters where server_id = p_server_id and owner = me and not converted for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Monstro inválido');
  end if;
  if v_m.starter then
    return jsonb_build_object('ok', false, 'error', 'O inicial não pode ser vendido');
  end if;
  v_snap := to_jsonb(v_m) - 'owner' || jsonb_build_object('level', greatest(1, least(p_level, v_vl + 10)));
  update monsters set owner = null where server_id = p_server_id;
  insert into market_listings(seller, seller_name, kind, currency, monster_id, monster, price)
    values (me, v_name, 'monster', 'diamonds', p_server_id, v_snap, p_price) returning * into v_listing;
  return jsonb_build_object('ok', true, 'listing', to_jsonb(v_listing), 'wallet', _wallet(me));
end $$;

-- comprar (ouro para itens/essências, diamantes para monstros) ----------------------
create or replace function public.market_buy(p_listing bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_l market_listings%rowtype;
  v_bal bigint;
  v_net bigint;
  v_have int;
begin
  if me is null then raise exception 'não autenticado'; end if;
  delete from market_listings where id = p_listing and seller <> me returning * into v_l;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Listagem não existe mais');
  end if;
  if v_l.currency = 'diamonds' then
    select diamonds into v_bal from players where id = me for update;
    if v_bal < v_l.price then raise exception 'Diamantes insuficientes'; end if;
    v_net := floor(v_l.price * 0.9);
    update players set diamonds = diamonds - v_l.price, version = version + 1 where id = me;
    update players set diamonds = diamonds + v_net, version = version + 1 where id = v_l.seller;
  else
    select gold into v_bal from players where id = me for update;
    if v_bal < v_l.price then raise exception 'Ouro insuficiente'; end if;
    v_net := floor(v_l.price * (1 - _market_cfg('fee')));
    update players set gold = gold - v_l.price, version = version + 1 where id = me;
    update players set gold = gold + v_net, version = version + 1 where id = v_l.seller;
  end if;
  if v_l.kind = 'item' then
    update items set owner = me where uid = v_l.item_uid;
  elsif v_l.kind = 'monster' then
    update monsters set owner = me, starter = false where server_id = v_l.monster_id;
  else
    select coalesce((essences->>v_l.essence_type)::int, 0) into v_have from players where id = me;
    update players set essences = jsonb_set(essences, array[v_l.essence_type], to_jsonb(v_have + v_l.amount)), version = version + 1 where id = me;
  end if;
  insert into market_sales(listing, seller, buyer, price, net) values (to_jsonb(v_l), v_l.seller, me, v_l.price, v_net);
  return jsonb_build_object('ok', true, 'item', coalesce(v_l.item, '{}'::jsonb), 'monster', coalesce(v_l.monster, '{}'::jsonb),
                            'essence_type', coalesce(v_l.essence_type, ''), 'amount', coalesce(v_l.amount, 0), 'wallet', _wallet(me));
exception when raise_exception then
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

-- cancelar ------------------------------------------------------------------------
create or replace function public.market_cancel(p_listing bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_l market_listings%rowtype;
  v_have int;
begin
  if me is null then raise exception 'não autenticado'; end if;
  delete from market_listings where id = p_listing and seller = me returning * into v_l;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Listagem inválida');
  end if;
  if v_l.kind = 'item' then
    update items set owner = me where uid = v_l.item_uid;
  elsif v_l.kind = 'monster' then
    update monsters set owner = me where server_id = v_l.monster_id;
  else
    select coalesce((essences->>v_l.essence_type)::int, 0) into v_have from players where id = me for update;
    update players set essences = jsonb_set(essences, array[v_l.essence_type], to_jsonb(v_have + v_l.amount)), version = version + 1 where id = me;
  end if;
  return jsonb_build_object('ok', true, 'item', coalesce(v_l.item, '{}'::jsonb), 'monster', coalesce(v_l.monster, '{}'::jsonb),
                            'essence_type', coalesce(v_l.essence_type, ''), 'amount', coalesce(v_l.amount, 0), 'wallet', _wallet(me));
end $$;

-- busca: monstros só aparecem pedindo kind = 'monster' -----------------------------
create or replace function public.market_search(f jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from (
    select * from market_listings l
    where l.seller <> me
      and ((coalesce(f->>'kind', '') = '' and l.kind <> 'monster') or l.kind = f->>'kind')
      and (coalesce(f->>'slot', '') = '' or l.slot = f->>'slot')
      and (coalesce(f->>'rarity', '') = '' or l.rarity = f->>'rarity')
      and (coalesce((f->>'min_enh')::int, 0) = 0 or l.enh >= (f->>'min_enh')::int)
      and (coalesce(f->>'item_type', '') = '' or l.item_type = f->>'item_type')
      and (coalesce(f->>'essence_type', '') = '' or l.essence_type = f->>'essence_type')
      and (coalesce(f->>'stat', '') = '' or (l.item->'affixes') @> jsonb_build_array(jsonb_build_object('id', f->>'stat'))
           or (f->>'stat' in ('hp', 'atk', 'def', 'spd_pct', 'crit')))
      and (coalesce((f->>'shiny_only')::boolean, false) = false or (l.monster->>'shiny')::boolean)
      and (coalesce((f->>'min_quality')::int, 0) = 0 or coalesce((l.monster->>'quality')::int, 0) >= (f->>'min_quality')::int)
    order by
      case when f->>'sort' = 'price_desc' then -l.price end,
      case when f->>'sort' = 'newest' then extract(epoch from l.created_at) * -1 end,
      l.price asc
    limit 200
  ) x;
  return jsonb_build_object('ok', true, 'listings', v);
end $$;

revoke all on function public.market_list_monster(text, int, bigint) from public, anon;
grant execute on function public.market_list_monster(text, int, bigint) to authenticated;
