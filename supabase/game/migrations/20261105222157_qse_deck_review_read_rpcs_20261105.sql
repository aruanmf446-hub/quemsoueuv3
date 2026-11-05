-- Supabase GAME shuzporktifgiotvnpbz
-- PROD MIGRATION: 20261105222157 qse_deck_review_read_rpcs_20261105
-- Already applied; do not reexecute.
CREATE OR REPLACE FUNCTION public.qse_deck_review_access()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object('is_moderator',
   coalesce(qse_v3.deck_review_is_moderator(),false))
$function$


CREATE OR REPLACE FUNCTION public.qse_deck_review_queue(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_items jsonb;
begin
 if auth.uid() is null then return jsonb_build_object('error','unauthorized'); end if;
 if not qse_v3.deck_review_is_moderator() then return jsonb_build_object('error','forbidden'); end if;
 if p_limit is null or p_limit not between 1 and 100 then
   return jsonb_build_object('error','invalid_limit'); end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'status',d.status)
  order by d.updated_at,d.id),'[]'::jsonb) into v_items
 from (select id,name,status,updated_at from public.qse_creator_decks
       where status='pending_review' order by updated_at,id limit p_limit) d;
 return jsonb_build_object('items',v_items);
end
$function$


CREATE OR REPLACE FUNCTION public.qse_deck_review_detail(p_deck uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_deck jsonb;v_cards jsonb;
begin
 if auth.uid() is null then return jsonb_build_object('error','unauthorized'); end if;
 if not qse_v3.deck_review_is_moderator() then return jsonb_build_object('error','forbidden'); end if;

 select jsonb_build_object(
  'id',d.id,'name',d.name,'description',d.description,'status',d.status,
  'creator',jsonb_build_object('nickname',p.nickname),
  'cover_path',coalesce(
   case when d.cover_mode='upload' and d.cover_image_path =
       d.owner_id::text||'/'||d.id::text||'/deck_cover.png'
     and exists(select 1 from storage.objects o
       where o.bucket_id='qse-deck-originals' and o.name=d.cover_image_path)
     then d.cover_image_path
    when d.cover_mode='card' and d.cover_card_id is not null
     and exists(select 1 from public.qse_creator_cards c
       join storage.objects o on o.bucket_id='qse-deck-originals'
        and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
       where c.id=d.cover_card_id and c.deck_id=d.id and c.owner_id=d.owner_id)
     then d.owner_id::text||'/'||d.id::text||'/'||d.cover_card_id::text||'_library.png'
    else null end,
   (select c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
    from public.qse_creator_cards c join storage.objects o
     on o.bucket_id='qse-deck-originals'
     and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
    where c.deck_id=d.id and c.owner_id=d.owner_id order by c.position,c.id limit 1))
 ) into v_deck
 from public.qse_creator_decks d
 left join qse_v3.player_profiles p on p.user_id=d.owner_id
 where d.id=p_deck and d.status='pending_review';

 if v_deck is null then return jsonb_build_object('error','deck_not_found'); end if;

 select coalesce(jsonb_agg(jsonb_build_object(
  'id',c.id,'name',c.name,
  'preview_library_path',case when exists(
     select 1 from storage.objects o where o.bucket_id='qse-deck-originals'
      and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png')
    then c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
    else null end,
  'preview_duel_path',case when exists(
     select 1 from storage.objects o where o.bucket_id='qse-deck-originals'
      and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png')
    then c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png'
    else null end
 ) order by c.position,c.id),'[]'::jsonb) into v_cards
 from public.qse_creator_cards c where c.deck_id=p_deck;

 return jsonb_build_object('deck',v_deck,'cards',v_cards);
end
$function$

revoke all on function public.qse_deck_review_access() from public,anon,authenticated;
grant execute on function public.qse_deck_review_access() to authenticated;
revoke all on function public.qse_deck_review_queue(integer) from public,anon,authenticated;
grant execute on function public.qse_deck_review_queue(integer) to authenticated;
revoke all on function public.qse_deck_review_detail(uuid) from public,anon,authenticated;
grant execute on function public.qse_deck_review_detail(uuid) to authenticated;