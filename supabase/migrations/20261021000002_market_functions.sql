-- =====================================================================
-- Market: transações ATÔMICAS (tudo ou nada) com bloqueio de linhas.
-- Chamadas pela Edge Function "game" com o JWT do usuário (auth.uid()).
-- Impossível duplicar item: o item muda de dono dentro da mesma transação
-- e a listagem é removida com DELETE ... RETURNING.
-- =====================================================================

create or replace function public._market_cfg(key text) returns numeric
language sql immutable as $$
  select case key
    when 'fee' then 0.05
    when 'max_listings' then 10
    when 'min_price' then 1
    when 'max_price' then 999999999
  end::numeric;
$$;

create or replace function public._wallet(p uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('gold', gold, 'essences', essences) from players where id = p;
$$;

-- listar item negociável -------------------------------------------------
create or replace function public.market_list_item(p_uid text, p_price bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_item items%rowtype;
  v_name text;
  v_count int;
  v_listing market_listings%rowtype;
begin
  if me is null then raise exception 'não autenticado'; end if;
  if p_price < _market_cfg('min_price') or p_price > _market_cfg('max_price') then
    return jsonb_build_object('ok', false, 'error', 'Preço inválido');
  end if;
  perform 1 from players where id = me for update;
  select count(*) into v_count from market_listings where seller = me;
  if v_count >= _market_cfg('max_listings') then
    return jsonb_build_object('ok', false, 'error', 'Limite de listagens atingido');
  end if;
  select * into v_item from items where uid = p_uid and owner = me for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Item não encontrado ou não negociável');
  end if;
  select name into v_name from players where id = me;
  update items set owner = null where uid = p_uid;
  insert into market_listings(seller, seller_name, kind, item_uid, item, price)
    values (me, v_name, 'item', p_uid, v_item.data, p_price) returning * into v_listing;
  return jsonb_build_object('ok', true, 'listing', to_jsonb(v_listing), 'wallet', _wallet(me));
end $$;

-- listar essência ---------------------------------------------------------
create or replace function public.market_list_essence(p_type text, p_amount int, p_price bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_have int;
  v_count int;
  v_name text;
  v_listing market_listings%rowtype;
begin
  if me is null then raise exception 'não autenticado'; end if;
  if p_amount <= 0 or p_price < _market_cfg('min_price') or p_price > _market_cfg('max_price') then
    return jsonb_build_object('ok', false, 'error', 'Valores inválidos');
  end if;
  select coalesce((essences->>p_type)::int, 0), name into v_have, v_name from players where id = me for update;
  if v_have < p_amount then
    return jsonb_build_object('ok', false, 'error', 'Essência insuficiente');
  end if;
  select count(*) into v_count from market_listings where seller = me;
  if v_count >= _market_cfg('max_listings') then
    return jsonb_build_object('ok', false, 'error', 'Limite de listagens atingido');
  end if;
  update players set essences = jsonb_set(essences, array[p_type], to_jsonb(v_have - p_amount)), version = version + 1 where id = me;
  insert into market_listings(seller, seller_name, kind, essence_type, amount, price)
    values (me, v_name, 'essence', p_type, p_amount, p_price) returning * into v_listing;
  return jsonb_build_object('ok', true, 'listing', to_jsonb(v_listing), 'wallet', _wallet(me));
end $$;

-- comprar -----------------------------------------------------------------
create or replace function public.market_buy(p_listing bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_l market_listings%rowtype;
  v_gold bigint;
  v_net bigint;
  v_have int;
begin
  if me is null then raise exception 'não autenticado'; end if;
  -- remove a listagem de forma atômica: só um comprador consegue
  delete from market_listings where id = p_listing and seller <> me returning * into v_l;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Listagem não existe mais');
  end if;
  select gold into v_gold from players where id = me for update;
  if v_gold < v_l.price then
    raise exception 'Ouro insuficiente';  -- desfaz o DELETE
  end if;
  v_net := floor(v_l.price * (1 - _market_cfg('fee')));
  update players set gold = gold - v_l.price, version = version + 1 where id = me;
  update players set gold = gold + v_net, version = version + 1 where id = v_l.seller;
  if v_l.kind = 'item' then
    update items set owner = me where uid = v_l.item_uid;
  else
    select coalesce((essences->>v_l.essence_type)::int, 0) into v_have from players where id = me;
    update players set essences = jsonb_set(essences, array[v_l.essence_type], to_jsonb(v_have + v_l.amount)), version = version + 1 where id = me;
  end if;
  insert into market_sales(listing, seller, buyer, price, net) values (to_jsonb(v_l), v_l.seller, me, v_l.price, v_net);
  return jsonb_build_object('ok', true, 'item', coalesce(v_l.item, '{}'::jsonb), 'essence_type', coalesce(v_l.essence_type, ''),
                            'amount', coalesce(v_l.amount, 0), 'wallet', _wallet(me));
exception when raise_exception then
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

-- cancelar ----------------------------------------------------------------
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
  else
    select coalesce((essences->>v_l.essence_type)::int, 0) into v_have from players where id = me for update;
    update players set essences = jsonb_set(essences, array[v_l.essence_type], to_jsonb(v_have + v_l.amount)), version = version + 1 where id = me;
  end if;
  return jsonb_build_object('ok', true, 'item', coalesce(v_l.item, '{}'::jsonb), 'essence_type', coalesce(v_l.essence_type, ''),
                            'amount', coalesce(v_l.amount, 0), 'wallet', _wallet(me));
end $$;

-- minhas listagens + vendas não notificadas -------------------------------
create or replace function public.market_my()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_listings jsonb;
  v_sales jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(l) order by l.created_at desc), '[]'::jsonb) into v_listings
    from market_listings l where l.seller = me;
  with s as (
    update market_sales set notified = true where seller = me and not notified returning listing, net
  ) select coalesce(jsonb_agg(jsonb_build_object('listing', listing, 'net', net)), '[]'::jsonb) into v_sales from s;
  return jsonb_build_object('ok', true, 'listings', v_listings, 'sales', v_sales, 'wallet', _wallet(me));
end $$;

-- busca com filtros --------------------------------------------------------
create or replace function public.market_search(f jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from (
    select * from market_listings l
    where l.seller <> me
      and (coalesce(f->>'kind', '') = '' or l.kind = f->>'kind')
      and (coalesce(f->>'slot', '') = '' or l.slot = f->>'slot')
      and (coalesce(f->>'rarity', '') = '' or l.rarity = f->>'rarity')
      and (coalesce((f->>'min_enh')::int, 0) = 0 or l.enh >= (f->>'min_enh')::int)
      and (coalesce(f->>'item_type', '') = '' or l.item_type = f->>'item_type')
      and (coalesce(f->>'essence_type', '') = '' or l.essence_type = f->>'essence_type')
      and (coalesce(f->>'stat', '') = '' or (l.item->'affixes') @> jsonb_build_array(jsonb_build_object('id', f->>'stat'))
           or (f->>'stat' in ('hp', 'atk', 'def', 'spd_pct', 'crit')))
    order by
      case when f->>'sort' = 'price_desc' then -l.price end,
      case when f->>'sort' = 'newest' then extract(epoch from l.created_at) * -1 end,
      l.price asc
    limit 100
  ) x;
  return jsonb_build_object('ok', true, 'listings', v);
end $$;

revoke all on function public.market_list_item(text, bigint) from public, anon;
revoke all on function public.market_list_essence(text, int, bigint) from public, anon;
revoke all on function public.market_buy(bigint) from public, anon;
revoke all on function public.market_cancel(bigint) from public, anon;
revoke all on function public.market_my() from public, anon;
revoke all on function public.market_search(jsonb) from public, anon;
grant execute on function public.market_list_item(text, bigint) to authenticated;
grant execute on function public.market_list_essence(text, int, bigint) to authenticated;
grant execute on function public.market_buy(bigint) to authenticated;
grant execute on function public.market_cancel(bigint) to authenticated;
grant execute on function public.market_my() to authenticated;
grant execute on function public.market_search(jsonb) to authenticated;

-- limpeza periódica (agende com pg_cron se disponível):
-- select cron.schedule('limpa-tickets', '0 * * * *', $$delete from public.spawn_tickets where created_at < now() - interval '6 hours'$$);
