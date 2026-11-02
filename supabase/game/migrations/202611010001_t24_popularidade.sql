-- T24/1 GAME — Popularidade, dados agregados sem exposição de jogadores.
create table if not exists public.qse_deck_plays (
 id uuid primary key default gen_random_uuid(),
 deck_ref text not null check (deck_ref ~ '^official:[a-z0-9_]{2,64}$' or deck_ref ~ '^creator:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
 user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 played_at timestamptz not null default now(),
 played_hour timestamp generated always as (date_trunc('hour',played_at at time zone 'UTC')) stored,
 unique (user_id,deck_ref,played_hour)
);
create index if not exists qse_deck_plays_30d_idx on public.qse_deck_plays (deck_ref, played_at desc) include (user_id);
alter table public.qse_deck_plays enable row level security;
drop policy if exists qse_deck_plays_insert_own on public.qse_deck_plays;
create policy qse_deck_plays_insert_own on public.qse_deck_plays
 for insert to authenticated with check ((select auth.uid()) = user_id);
revoke all on public.qse_deck_plays from public,anon,authenticated;
-- Nenhum INSERT direto: somente RPC valida o deck e fixa played_at no servidor.
-- RLS permanece como defesa em profundidade, sem SELECT de participantes.

create or replace function public.qse_deck_record_play(p_deck_ref text)
 returns jsonb language plpgsql security definer set search_path = ''
 as $$
 declare v_user uuid := auth.uid(); v_new uuid; v_at timestamptz;
 begin
  if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
  if p_deck_ref is null or (p_deck_ref !~ '^official:[a-z0-9_]{2,64}$' and p_deck_ref !~ '^creator:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    return jsonb_build_object('error','invalid_deck_ref');
  end if;
  if left(p_deck_ref,9)='official:' then
    if not exists(select 1 from qse_v3.duel_decks where id = substring(p_deck_ref from 10)) then
      return jsonb_build_object('error','deck_not_found');
    end if;
  elsif not exists(select 1 from public.qse_creator_decks d where d.id=substring(p_deck_ref from 9)::uuid
    and (d.owner_id=v_user or d.status='published')) then
      return jsonb_build_object('error','deck_not_found');
  end if;
  insert into public.qse_deck_plays(deck_ref,user_id)
   values(p_deck_ref,v_user) on conflict (user_id,deck_ref,played_hour) do nothing
   returning id,played_at into v_new,v_at;
  return jsonb_build_object('deck_ref',p_deck_ref,'recorded',v_new is not null,
    'played_at',v_at,'reason',case when v_new is null then 'duplicate_hour' else null end);
 end;
 $$;
revoke all on function public.qse_deck_record_play(text) from public,anon,authenticated;
grant execute on function public.qse_deck_record_play(text) to authenticated;

create or replace function public.qse_deck_stats(p_refs text[])
 returns jsonb language plpgsql security definer set search_path = ''
 as $$
 declare v_user uuid := auth.uid(); v_result jsonb;
 begin
  if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
  if p_refs is null or cardinality(p_refs)>100 or exists (
    select 1 from unnest(p_refs) r
    where r is null or (r !~ '^official:[a-z0-9_]{2,64}$' and r !~ '^creator:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
  ) then return jsonb_build_object('error','invalid_refs'); end if;
  with refs as (select distinct ref as deck_ref from unnest(p_refs) ref),
  plays as (
    select p.deck_ref,count(*)::integer plays_30d,
           count(distinct p.user_id)::integer players_30d
    from public.qse_deck_plays p join refs r on r.deck_ref=p.deck_ref
    where p.played_at >= now()-interval '30 days'
    group by p.deck_ref
  ),
  favs as (
    select f.deck_ref,count(*)::integer favorites
    from public.qse_deck_favorites f join refs r on r.deck_ref=f.deck_ref
    group by f.deck_ref
  )
  select coalesce(jsonb_agg(jsonb_build_object(
   'deck_ref',r.deck_ref,
   'plays_30d',coalesce(p.plays_30d,0),
   'players_30d',coalesce(p.players_30d,0),
   'favorites',coalesce(f.favorites,0),
   'score',((coalesce(p.players_30d,0)*2 + coalesce(p.plays_30d,0) + coalesce(f.favorites,0)*3)::numeric)
  ) order by r.deck_ref),'[]'::jsonb) into v_result
  from refs r left join plays p on p.deck_ref=r.deck_ref
              left join favs f on f.deck_ref=r.deck_ref;
  return v_result;
 end;
 $$;
revoke all on function public.qse_deck_stats(text[]) from public,anon,authenticated;
grant execute on function public.qse_deck_stats(text[]) to authenticated;
