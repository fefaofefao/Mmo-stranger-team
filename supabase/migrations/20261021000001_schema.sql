-- =====================================================================
-- Bestiário Idle — schema do servidor (Supabase / Postgres)
-- Tudo que tem valor de troca é escrito SOMENTE pela Edge Function "game"
-- (service role) ou por funções SECURITY DEFINER com validação.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- jogadores
create table if not exists public.players (
  id               uuid primary key references auth.users(id) on delete cascade,
  name             text not null default ('Jogador' || floor(random() * 9000 + 1000)::int),
  created_at       timestamptz not null default now(),
  last_claim_at    timestamptz not null default now(),
  last_seen_at     timestamptz not null default now(),
  gold             bigint not null default 0 check (gold >= 0),
  essences         jsonb not null default '{}'::jsonb,
  npc_budget       numeric not null default 0,
  validated_level  int not null default 1,
  validated_at     timestamptz not null default now(),
  stats            jsonb not null default '{"kills":0}'::jsonb,
  weekly           jsonb not null default '{}'::jsonb,
  last_offline     jsonb not null default '{}'::jsonb,
  google_linked    boolean not null default false,
  cloud_save       jsonb,
  cloud_saved_at   timestamptz,
  version          bigint not null default 0,
  flagged          int not null default 0
);

-- registro de monstros emitidos pelo servidor (inicial + recrutados)
create table if not exists public.monsters (
  server_id   text primary key,
  owner       uuid not null references public.players(id) on delete cascade,
  family      text not null,
  form        text not null,
  shiny       boolean not null default false,
  stars       int not null default 0 check (stars between 0 and 5),
  converted   boolean not null default false,
  starter     boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists monsters_owner_idx on public.monsters(owner);

-- itens negociáveis (Raro+). owner = null enquanto listado no market.
create table if not exists public.items (
  uid         text primary key,
  owner       uuid references public.players(id) on delete set null,
  data        jsonb not null,
  created_at  timestamptz not null default now()
);
create index if not exists items_owner_idx on public.items(owner);

-- tickets de spawn (shiny sorteado no servidor)
create table if not exists public.spawn_tickets (
  id          text primary key,
  owner       uuid not null references public.players(id) on delete cascade,
  hunt        text not null,
  shiny       boolean not null default false,
  used        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists spawn_tickets_owner_idx on public.spawn_tickets(owner, used);

create table if not exists public.challenge_records (
  owner        uuid not null references public.players(id) on delete cascade,
  challenge_id text not null,
  cleared      boolean not null default false,
  best         numeric not null default 0,
  last_fail    timestamptz,
  week         int not null default 0,
  week_best    numeric not null default 0,
  primary key (owner, challenge_id)
);

-- ---------------------------------------------------------------- market
create table if not exists public.market_listings (
  id            bigserial primary key,
  seller        uuid not null references public.players(id) on delete cascade,
  seller_name   text not null,
  kind          text not null check (kind in ('item', 'essence')),
  item_uid      text references public.items(uid),
  item          jsonb,
  essence_type  text,
  amount        int,
  price         bigint not null check (price > 0),
  created_at    timestamptz not null default now(),
  -- colunas de filtro derivadas do item
  slot          text generated always as (split_part(item->>'base', '_', 1)) stored,
  rarity        text generated always as (item->>'rarity') stored,
  enh           int generated always as (coalesce((item->>'enh')::int, 0)) stored,
  item_type     text generated always as (split_part(item->>'base', '_', 2)) stored
);
create index if not exists market_filter_idx on public.market_listings(kind, slot, rarity, enh, price);
create index if not exists market_seller_idx on public.market_listings(seller);
create unique index if not exists market_item_unique on public.market_listings(item_uid) where item_uid is not null;

create table if not exists public.market_sales (
  id          bigserial primary key,
  listing     jsonb not null,
  seller      uuid not null,
  buyer       uuid not null,
  price       bigint not null,
  net         bigint not null,
  notified    boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists market_sales_seller_idx on public.market_sales(seller, notified);

-- ---------------------------------------------------------------- RLS
alter table public.players            enable row level security;
alter table public.monsters           enable row level security;
alter table public.items              enable row level security;
alter table public.spawn_tickets      enable row level security;
alter table public.challenge_records  enable row level security;
alter table public.market_listings    enable row level security;
alter table public.market_sales       enable row level security;

-- leitura apenas dos próprios dados; nenhuma escrita direta pelo cliente
create policy players_select_own   on public.players           for select using (auth.uid() = id);
create policy monsters_select_own  on public.monsters          for select using (auth.uid() = owner);
create policy items_select_own     on public.items             for select using (auth.uid() = owner);
create policy tickets_select_own   on public.spawn_tickets     for select using (auth.uid() = owner);
create policy challenges_select_own on public.challenge_records for select using (auth.uid() = owner);
create policy sales_select_own     on public.market_sales      for select using (auth.uid() = seller or auth.uid() = buyer);
-- o market é público para leitura (usuários autenticados)
create policy market_select_all    on public.market_listings   for select to authenticated using (true);

-- (sem políticas de insert/update/delete => negado para anon/authenticated; a service role ignora RLS)

-- ---------------------------------------------------------------- ranking (views)
create or replace view public.ranking_global as
select p.id, p.name,
       p.validated_level                                   as level,
       coalesce((p.stats->>'collection')::int, 0)          as collection,
       (select count(*) from public.monsters m where m.owner = p.id and m.shiny)                       as shinies,
       (select coalesce(sum(m.stars), 0) from public.monsters m where m.owner = p.id and not m.converted) as stars
from public.players p
where p.flagged < 3;
