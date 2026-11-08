-- Downloads = jogadores únicos que adicionaram o deck à biblioteca. Não conta prévias/requests.
-- Compatível com clientes antigos; somente agregados, sem identidades.
begin;
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
  ),
  downloads as (
    select 'creator:'||c.deck_id::text deck_ref,count(*)::integer downloads
    from public.qse_community_claims c join refs r on r.deck_ref='creator:'||c.deck_id::text
    group by c.deck_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
   'deck_ref',r.deck_ref,
   'plays_30d',coalesce(p.plays_30d,0),
   'players_30d',coalesce(p.players_30d,0),
   'favorites',coalesce(f.favorites,0),
   'downloads',coalesce(d.downloads,0),
   'score',((coalesce(p.players_30d,0)*2 + coalesce(p.plays_30d,0) + coalesce(f.favorites,0)*3)::numeric)
  ) order by r.deck_ref),'[]'::jsonb) into v_result
  from refs r left join plays p on p.deck_ref=r.deck_ref
              left join favs f on f.deck_ref=r.deck_ref
              left join downloads d on d.deck_ref=r.deck_ref;
  return v_result;
 end;
 $$;
revoke all on function public.qse_deck_stats(text[]) from public,anon,authenticated;
grant execute on function public.qse_deck_stats(text[]) to authenticated;

commit;
