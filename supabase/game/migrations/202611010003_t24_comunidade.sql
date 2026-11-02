-- T24/3 GAME — Comunidade. Adições compatíveis com T20/T21.
alter table public.qse_creator_decks drop constraint qse_creator_decks_status_check;
alter table public.qse_creator_decks add constraint qse_creator_decks_status_check
 check(status in ('draft','pending_review','published','rejected','removed'));
alter table public.qse_creator_decks drop constraint qse_creator_decks_visibility_check;
alter table public.qse_creator_decks add constraint qse_creator_decks_visibility_check
 check(visibility in ('private','public','unlisted'));
alter table public.qse_creator_decks add column if not exists review_note text;
alter table public.qse_creator_decks add constraint qse_t24_review_note_length
 check(review_note is null or char_length(review_note)<=1000);
create index if not exists qse_creator_decks_published_idx
 on public.qse_creator_decks(published_at desc,id)
 where status='published';
-- Já existe qse_creator_cards_deck_position_idx com os mesmos campos.

-- O dono pode editar metadados do RASCUNHO, mas nunca status/review_note/visibility/published_at diretamente.
create or replace function qse_v3.t24_deck_guard()
returns trigger language plpgsql security invoker set search_path=''
as $$
begin
 if tg_op='UPDATE' then
   if current_user='authenticated' and
      (new.status is distinct from old.status
       or new.visibility is distinct from old.visibility
       or new.review_note is distinct from old.review_note
       or new.published_at is distinct from old.published_at) then
      raise exception 'moderated_fields_read_only' using errcode='42501';
   end if;
   if current_user='authenticated' and old.status<>'draft' then
      raise exception 'deck_locked' using errcode='42501';
   end if;
 end if;
 if current_user='authenticated' and new.status<>'draft' then
   raise exception 'moderated_fields_read_only' using errcode='42501';
 end if;
 if new.status='published' then new.visibility:='public';
 else new.visibility:='private'; end if;
 return new;
end;
$$;
drop trigger if exists qse_t24_deck_guard on public.qse_creator_decks;
create trigger qse_t24_deck_guard before insert or update on public.qse_creator_decks
 for each row execute function qse_v3.t24_deck_guard();

create or replace function qse_v3.t24_card_guard()
returns trigger language plpgsql security invoker set search_path=''
as $$
declare v_deck uuid; v_status text;
begin
 v_deck:=case when tg_op='DELETE' then old.deck_id else new.deck_id end;
 select status into v_status from public.qse_creator_decks where id=v_deck;
 if current_user='authenticated' and v_status is distinct from 'draft' then
    raise exception 'deck_locked' using errcode='42501';
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end;
$$;
drop trigger if exists qse_t24_card_guard on public.qse_creator_cards;
create trigger qse_t24_card_guard before insert or update or delete on public.qse_creator_cards
 for each row execute function qse_v3.t24_card_guard();

-- Só o dono pode pedir publicação; exigência de imagens + DUAS prévias existentes no Storage.
create or replace function public.qse_deck_publish_request(p_deck uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_status text; v_total integer; v_valid integer;
begin
 if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
 select status into v_status from public.qse_creator_decks
 where id=p_deck and owner_id=v_user for update;
 if not found then return jsonb_build_object('error','deck_not_found'); end if;
 if v_status not in ('draft','rejected') then
    return jsonb_build_object('error','invalid_status'); end if;
 select count(*),count(*) filter (where
   nullif(btrim(c.name),'') is not null
   and c.image_original_path is not null
   and exists(select 1 from storage.objects o where o.bucket_id='qse-deck-originals'
              and o.name=c.image_original_path)
   and exists(select 1 from storage.objects o where o.bucket_id='qse-deck-originals'
              and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png')
   and exists(select 1 from storage.objects o where o.bucket_id='qse-deck-originals'
              and o.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png')
 ) into v_total,v_valid from public.qse_creator_cards c where c.deck_id=p_deck;
 if v_total<5 then return jsonb_build_object('error','min_cards','minimum',5,'actual',v_total); end if;
 if v_valid<>v_total then return jsonb_build_object('error','missing_images_or_previews','valid',v_valid,'total',v_total); end if;
 update public.qse_creator_decks set status='pending_review',review_note=null where id=p_deck;
 return jsonb_build_object('deck_id',p_deck,'status','pending_review');
end;
$$;

create or replace function public.qse_deck_unpublish(p_deck uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_status text;
begin
 if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
 select status into v_status from public.qse_creator_decks
 where id=p_deck and owner_id=v_user for update;
 if not found then return jsonb_build_object('error','deck_not_found'); end if;
 if v_status='removed' then return jsonb_build_object('error','removed'); end if;
 update public.qse_creator_decks set status='draft',visibility='private'
 where id=p_deck and status<>'draft';
 return jsonb_build_object('deck_id',p_deck,'status','draft');
end;
$$;

-- 1 denúncia global por usuário/deck. Após 3 jogadores distintos NESTE ciclo de publicação, reabre revisão.
create table if not exists public.qse_deck_reports(
 deck_id uuid not null references public.qse_creator_decks(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 reason text not null check(char_length(btrim(reason)) between 1 and 280),
 reported_at timestamptz not null default now(),
 primary key(deck_id,user_id)
);
create index if not exists qse_deck_reports_window_idx on public.qse_deck_reports(deck_id,reported_at desc);
alter table public.qse_deck_reports enable row level security;
revoke all on public.qse_deck_reports from public,anon,authenticated;

create or replace function public.qse_deck_report(p_deck uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_owner uuid; v_published timestamptz; v_status text; v_count integer;
begin
 if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
 if p_reason is null or char_length(btrim(p_reason)) not between 1 and 280 then
   return jsonb_build_object('error','invalid_reason'); end if;
 select owner_id,published_at,status into v_owner,v_published,v_status
 from public.qse_creator_decks where id=p_deck for update;
 if not found or v_status<>'published' then
   return jsonb_build_object('error','deck_not_published'); end if;
 if v_owner=v_user then return jsonb_build_object('error','cannot_report_own'); end if;
 if exists(select 1 from public.qse_deck_reports where deck_id=p_deck and user_id=v_user) then
   return jsonb_build_object('error','already_reported'); end if;
 insert into public.qse_deck_reports(deck_id,user_id,reason)
 values(p_deck,v_user,btrim(p_reason));
 select count(*) into v_count from public.qse_deck_reports
 where deck_id=p_deck and reported_at>=v_published;
 if v_count>=3 then
   update public.qse_creator_decks set status='pending_review',visibility='private'
   where id=p_deck;
 end if;
 return jsonb_build_object('reported',true,'deck_id',p_deck,'status',
   case when v_count>=3 then 'pending_review' else 'published' end,
   'report_count',v_count);
end;
$$;

-- Validação interna de visibilidade apenas dos objetos de preview PUBLICADOS.
-- Não revela IDs de usuários, notas da moderação ou nomes de arquivos originais.
create or replace function public.qse_t24_published_preview(p_path text)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(
  select 1 from public.qse_creator_cards c
  join public.qse_creator_decks d on d.id=c.deck_id
  where d.status='published' and d.visibility='public'
   and p_path in (
     c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png',
     c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png'
   )
 );
$$;
drop policy if exists qse_deck_published_previews_read on storage.objects;
create policy qse_deck_published_previews_read on storage.objects for select to authenticated
 using (bucket_id='qse-deck-originals' and public.qse_t24_published_preview(name));

-- IMPORTANTE: NÃO criar policy de SELECT público em qse_creator_cards:
-- a tabela possui image_original_path, que só o dono deve ver.
create or replace function public.qse_community_deck(p_deck uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_deck jsonb; v_cards jsonb;
begin
 if v_uid is null then return jsonb_build_object('error','unauthorized'); end if;
 select jsonb_build_object(
  'id',d.id,'name',d.name,'description',d.description,'category',d.category,
  'card_count',(select count(*) from public.qse_creator_cards where deck_id=d.id),
  'published_at',d.published_at,
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
$$;

create or replace function public.qse_community_decks(
 p_query text default null,p_theme text default null,p_sort text default 'popular',
 p_limit integer default 24,p_cursor text default null
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
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
     (select c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
       from public.qse_creator_cards c
       where c.deck_id=d.id and public.qse_t24_published_preview(
        c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png')
       order by c.position,c.id limit 1) as cover_path,
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
$$;
revoke all on function qse_v3.t24_deck_guard() from public,anon,authenticated;
revoke all on function qse_v3.t24_card_guard() from public,anon,authenticated;
revoke all on function public.qse_deck_publish_request(uuid) from public,anon,authenticated;
revoke all on function public.qse_deck_unpublish(uuid) from public,anon,authenticated;
revoke all on function public.qse_deck_report(uuid,text) from public,anon,authenticated;
revoke all on function public.qse_community_deck(uuid) from public,anon,authenticated;
revoke all on function public.qse_community_decks(text,text,text,integer,text) from public,anon,authenticated;
revoke all on function public.qse_t24_published_preview(text) from public,anon,authenticated;
grant execute on function public.qse_deck_publish_request(uuid) to authenticated;
grant execute on function public.qse_deck_unpublish(uuid) to authenticated;
grant execute on function public.qse_deck_report(uuid,text) to authenticated;
grant execute on function public.qse_community_deck(uuid) to authenticated;
grant execute on function public.qse_community_decks(text,text,text,integer,text) to authenticated;
grant execute on function public.qse_t24_published_preview(text) to authenticated;
