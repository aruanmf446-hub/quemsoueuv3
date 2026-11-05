-- Supabase GAME shuzporktifgiotvnpbz
-- PROD MIGRATION: 20261105222227 qse_deck_review_atomic_decide_20261105
-- Already applied; do not reexecute.
CREATE OR REPLACE FUNCTION public.qse_deck_review_decide(p_deck uuid, p_approved boolean, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_deck public.qse_creator_decks%rowtype;
  v_total integer;v_valid integer;v_note text;
begin
  if v_uid is null then return jsonb_build_object('error','unauthorized'); end if;
  if not qse_v3.deck_review_is_moderator() then
    return jsonb_build_object('error','forbidden'); end if;
  if p_approved is null then return jsonb_build_object('error','invalid_contract'); end if;

  select * into v_deck from public.qse_creator_decks d
  where d.id=p_deck for update;
  if not found then return jsonb_build_object('error','deck_not_found'); end if;
  if v_deck.status<>'pending_review' then
    return jsonb_build_object('error','invalid_status'); end if;

  if p_approved then
    select count(*),count(*) filter(where
      nullif(btrim(c.name),'') is not null
      and c.image_original_path in (
        c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_original.png',
        c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_original.jpg',
        c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_original.jpeg',
        c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_original.webp'
      )
      and exists(select 1 from storage.objects o where
        o.bucket_id='qse-deck-originals' and o.name=c.image_original_path)
      and exists(select 1 from storage.objects o where
        o.bucket_id='qse-deck-originals'
        and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png')
      and exists(select 1 from storage.objects o where
        o.bucket_id='qse-deck-originals'
        and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png')
    ) into v_total,v_valid
    from public.qse_creator_cards c
    where c.deck_id=p_deck and c.owner_id=v_deck.owner_id;

    if v_total<5 then return jsonb_build_object(
      'error','min_cards','minimum',5,'actual',v_total); end if;
    if v_total>30 then return jsonb_build_object(
      'error','invalid_card_count','maximum',30,'actual',v_total); end if;
    if v_valid<>v_total then return jsonb_build_object(
      'error','missing_images_or_previews','valid',v_valid,'total',v_total); end if;

    if v_deck.cover_mode='upload' and (
      v_deck.cover_image_path is distinct from
      v_deck.owner_id::text||'/'||v_deck.id::text||'/deck_cover.png'
      or not exists(select 1 from storage.objects o
        where o.bucket_id='qse-deck-originals' and o.name=v_deck.cover_image_path)
    ) then return jsonb_build_object('error','missing_images_or_previews'); end if;

    if v_deck.cover_mode='card' and (
      v_deck.cover_card_id is null or
      not exists(select 1 from public.qse_creator_cards c
        where c.id=v_deck.cover_card_id and c.deck_id=v_deck.id
          and c.owner_id=v_deck.owner_id)
    ) then return jsonb_build_object('error','missing_images_or_previews'); end if;

    update public.qse_creator_decks
    set status='published',visibility='public',review_note=null
    where id=p_deck and status='pending_review';
    v_note:=null;
  else
    v_note:=btrim(coalesce(p_reason,''));
    if char_length(v_note) not between 3 and 280 then
      return jsonb_build_object('error','invalid_reason'); end if;
    update public.qse_creator_decks
    set status='rejected',visibility='private',review_note=v_note
    where id=p_deck and status='pending_review';
  end if;

  insert into public.qse_deck_review_decisions(
    deck_id,reviewer_id,approved,new_status,reason)
  values(p_deck,v_uid,p_approved,
    case when p_approved then 'published' else 'rejected' end,v_note);
  return jsonb_build_object(
    'deck_id',p_deck,
    'status',case when p_approved then 'published' else 'rejected' end,
    'review_note',v_note);
end
$function$;

revoke all on function public.qse_deck_review_decide(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.qse_deck_review_decide(uuid,boolean,text) to authenticated;
