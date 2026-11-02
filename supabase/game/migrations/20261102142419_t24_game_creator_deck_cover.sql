alter table public.qse_creator_decks
 add column cover_mode text not null default 'auto'
   constraint qse_creator_decks_cover_mode_check check (cover_mode in ('auto','card','upload')),
 add column cover_card_id uuid,
 add column cover_image_path text;
alter table public.qse_creator_decks
 add constraint qse_creator_decks_cover_card_id_fkey foreign key (cover_card_id)
 references public.qse_creator_cards(id) on delete set null;
alter table public.qse_creator_decks
 add constraint qse_creator_decks_cover_path_check
 check (cover_image_path is null or cover_image_path=owner_id::text||'/'||id::text||'/deck_cover.png');

create or replace function qse_v3.t24_validate_deck_cover()
returns trigger language plpgsql set search_path=''
as $function$
begin
 if new.cover_card_id is not null and not exists(
  select 1 from public.qse_creator_cards c
  where c.id=new.cover_card_id and c.deck_id=new.id and c.owner_id=new.owner_id
 ) then raise exception 'cover_card_not_in_deck' using errcode='23514'; end if;
 return new;
end $function$;
create trigger qse_t24_validate_deck_cover before insert or update of cover_card_id,owner_id,id
on public.qse_creator_decks for each row execute function qse_v3.t24_validate_deck_cover();

create or replace function public.qse_t24_published_cover(p_path text)
returns boolean language sql stable security definer set search_path=''
as $function$
 select exists(select 1 from public.qse_creator_decks d
  where d.status='published' and d.visibility='public'
    and d.cover_mode='upload'
    and d.cover_image_path=p_path
    and p_path=d.owner_id::text||'/'||d.id::text||'/deck_cover.png')
$function$;
revoke all on function public.qse_t24_published_cover(text) from public,anon,authenticated;
grant execute on function public.qse_t24_published_cover(text) to authenticated;

-- Permite a capa do proprietário em draft, mantendo o bucket privado.
create policy qse_t24_cover_insert_draft on storage.objects for insert to authenticated
 with check(bucket_id='qse-deck-originals' and owner_id=(select auth.uid())::text
 and name=(select auth.uid())::text||'/'||(storage.foldername(name))[2]||'/deck_cover.png'
 and exists(select 1 from public.qse_creator_decks d where d.owner_id=(select auth.uid())
    and d.id::text=(storage.foldername(name))[2] and d.status='draft'));

create policy qse_t24_cover_update_draft on storage.objects for update to authenticated
 using(bucket_id='qse-deck-originals' and owner_id=(select auth.uid())::text
 and storage.filename(name)='deck_cover.png'
 and exists(select 1 from public.qse_creator_decks d where d.owner_id=(select auth.uid())
    and d.id::text=(storage.foldername(name))[2] and d.status='draft'))
 with check(bucket_id='qse-deck-originals' and owner_id=(select auth.uid())::text
 and name=(select auth.uid())::text||'/'||(storage.foldername(name))[2]||'/deck_cover.png'
 and exists(select 1 from public.qse_creator_decks d where d.owner_id=(select auth.uid())
    and d.id::text=(storage.foldername(name))[2] and d.status='draft'));

create policy qse_t24_published_covers_read on storage.objects for select to authenticated
 using(bucket_id='qse-deck-originals' and public.qse_t24_published_cover(name));

-- Preserve all existing RPC parameters, sorting and return structures.
CREATE OR REPLACE FUNCTION public.qse_community_decks(p_query text DEFAULT NULL::text, p_theme text DEFAULT NULL::text, p_sort text DEFAULT 'popular'::text, p_limit integer DEFAULT 24, p_cursor text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid:=auth.uid(); v_offset integer:=0; v_items jsonb; v_more boolean; v_next text;
begin
 if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
 if p_sort is null or p_sort not in ('popular','recent','name') then return jsonb_build_object('error','invalid_sort'); end if;
 if p_limit is null or p_limit not between 1 and 48 then return jsonb_build_object('error','invalid_limit'); end if;
 if char_length(coalesce(p_query,''))>80 or char_length(coalesce(p_theme,''))>48 then return jsonb_build_object('error','invalid_filter'); end if;
 if nullif(p_cursor,'') is not null then
  begin
   v_offset:=convert_from(decode(p_cursor,'base64'),'UTF8')::integer;
   if v_offset<0 or v_offset>1000000 then return jsonb_build_object('error','invalid_cursor'); end if;
  exception when others then return jsonb_build_object('error','invalid_cursor');
  end;
 end if;
 with stats as (
   select deck_ref,count(*)::int plays,count(distinct user_id)::int players
   from public.qse_deck_plays
   where played_at >= now()-interval '30 days' and deck_ref like 'creator:%'
   group by deck_ref
 ), favs as (
   select deck_ref,count(*)::int fav from public.qse_deck_favorites
   where deck_ref like 'creator:%' group by deck_ref
 ), base as (
   select d.id,d.name,d.description,d.category,d.published_at,
     (select count(*)::int from public.qse_creator_cards c where c.deck_id=d.id) as card_count,
     coalesce(
  case
    when d.cover_mode='upload'
      and d.cover_image_path=d.owner_id::text||'/'||d.id::text||'/deck_cover.png'
      and exists(select 1 from storage.objects ob
          where ob.bucket_id='qse-deck-originals' and ob.name=d.cover_image_path)
    then d.cover_image_path
    when d.cover_mode='card'
      and exists(select 1 from public.qse_creator_cards cc
          join storage.objects ob on ob.bucket_id='qse-deck-originals'
           and ob.name=cc.owner_id::text||'/'||cc.deck_id::text||'/'||cc.id::text||'_library.png'
          where cc.id=d.cover_card_id and cc.deck_id=d.id and cc.owner_id=d.owner_id)
    then d.owner_id::text||'/'||d.id::text||'/'||d.cover_card_id::text||'_library.png'
    else null
  end,
  (select c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
   from public.qse_creator_cards c
   where c.deck_id=d.id and public.qse_t24_published_preview(
       c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png')
   order by c.position,c.id limit 1)
) as cover_path,
     jsonb_build_object('public_id',p.public_id,'nickname',p.nickname,
       'equipped_character_id',l.equipped_character_id,'level',s.level) as creator,
     (coalesce(st.players,0)*2+coalesce(st.plays,0)+coalesce(f.fav,0)*3)::numeric as score
   from public.qse_creator_decks d
   left join qse_v3.player_profiles p on p.user_id=d.owner_id
   left join qse_v3.player_loadout l on l.user_id=d.owner_id
   left join qse_v3.player_statistics s on s.user_id=d.owner_id
   left join stats st on st.deck_ref='creator:'||d.id::text
   left join favs f on f.deck_ref='creator:'||d.id::text
   where d.status='published' and d.visibility='public'
     and (nullif(btrim(p_query),'') is null or d.name ilike '%'||btrim(p_query)||'%' or d.description ilike '%'||btrim(p_query)||'%')
     and (nullif(btrim(p_theme),'') is null or d.category=p_theme)
 ), numbered as (
   select b.*,row_number() over(
     order by
       case when p_sort='popular' then score end desc nulls last,
       case when p_sort='recent' then published_at end desc nulls last,
       case when p_sort='name' then lower(name) end asc nulls last,
       id asc) as rn from base b
 ), page as (
   select * from numbered where rn>v_offset and rn<=v_offset+p_limit+1
 )
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',id,'name',name,'description',description,'category',category,
   'card_count',card_count,'cover_path',cover_path,'creator',creator,
   'published_at',published_at,'score',score
 ) order by rn) filter(where rn<=v_offset+p_limit),'[]'::jsonb),
 coalesce(bool_or(rn>v_offset+p_limit),false) into v_items,v_more from page;
 if v_more then v_next:=encode(convert_to((v_offset+p_limit)::text,'UTF8'),'base64'); end if;
 return jsonb_build_object('items',v_items,'next_cursor',v_next);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.qse_community_deck(p_deck uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_deck jsonb; v_cards jsonb;
begin
 if v_uid is null then return jsonb_build_object('error','unauthorized'); end if;
 select jsonb_build_object(
  'id',d.id,'name',d.name,'description',d.description,'category',d.category,
  'card_count',(select count(*) from public.qse_creator_cards where deck_id=d.id),
  'published_at',d.published_at,
  'cover_path',coalesce(
  case
    when d.cover_mode='upload'
      and d.cover_image_path=d.owner_id::text||'/'||d.id::text||'/deck_cover.png'
      and exists(select 1 from storage.objects ob
          where ob.bucket_id='qse-deck-originals' and ob.name=d.cover_image_path)
    then d.cover_image_path
    when d.cover_mode='card'
      and exists(select 1 from public.qse_creator_cards cc
          join storage.objects ob on ob.bucket_id='qse-deck-originals'
           and ob.name=cc.owner_id::text||'/'||cc.deck_id::text||'/'||cc.id::text||'_library.png'
          where cc.id=d.cover_card_id and cc.deck_id=d.id and cc.owner_id=d.owner_id)
    then d.owner_id::text||'/'||d.id::text||'/'||d.cover_card_id::text||'_library.png'
    else null
  end,
  (select c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
   from public.qse_creator_cards c
   where c.deck_id=d.id and public.qse_t24_published_preview(
       c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png')
   order by c.position,c.id limit 1)
),
  'creator',jsonb_build_object('public_id',p.public_id,'nickname',p.nickname,
         'equipped_character_id',l.equipped_character_id,'level',s.level)
 ) into v_deck
 from public.qse_creator_decks d
 left join qse_v3.player_profiles p on p.user_id=d.owner_id
 left join qse_v3.player_loadout l on l.user_id=d.owner_id
 left join qse_v3.player_statistics s on s.user_id=d.owner_id
 where d.id=p_deck and d.status='published' and d.visibility='public';
 if v_deck is null then return jsonb_build_object('error','deck_not_found'); end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'name',c.name,'description',c.description,
  'preview_library_path',case when public.qse_t24_published_preview(c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png')
    then c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png' else null end,
  'preview_duel_path',case when public.qse_t24_published_preview(c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png')
    then c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png' else null end,
  'crops',jsonb_build_object(
    'library',jsonb_build_object('center_x',c.portrait_center_x,'center_y',c.portrait_center_y,'zoom',c.portrait_zoom),
    'duel',jsonb_build_object('center_x',c.duel_center_x,'center_y',c.duel_center_y,'zoom',c.duel_zoom))
 ) order by c.position,c.id),'[]'::jsonb) into v_cards
 from public.qse_creator_cards c where c.deck_id=p_deck;
 return jsonb_build_object('deck',v_deck,'cards',v_cards);
end;
$function$
;
