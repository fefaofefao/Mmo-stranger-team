-- Marcos de Caça: abates validados por forma (bônus permanentes da conta calculados na Edge Function)
alter table public.players add column if not exists mastery jsonb not null default '{}'::jsonb;
