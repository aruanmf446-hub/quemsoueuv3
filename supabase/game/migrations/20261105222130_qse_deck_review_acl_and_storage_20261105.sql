-- Supabase GAME shuzporktifgiotvnpbz
-- PROD MIGRATION: 20261105222130 qse_deck_review_acl_and_storage_20261105
-- Applied 2026-11-05. Do not rerun applied migrations.
-- Source contract docs/backend/DECKS_STORAGE_REVISAO_MANUAL.md @ fcfdb23

create table public.qse_deck_reviewers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now(),
  grant_note text not null default 'confirmed_by_owner_2026_11_05'
);
alter table public.qse_deck_reviewers enable row level security;
revoke all on public.qse_deck_reviewers from public,anon,authenticated;

create table public.qse_deck_review_decisions (
  id bigint generated always as identity primary key,
  deck_id uuid not null,
  reviewer_id uuid references auth.users(id) on delete set null,
  approved boolean not null,
  previous_status text not null default 'pending_review',
  new_status text not null check(new_status in ('published','rejected')),
  reason text,
  decided_at timestamptz not null default now()
);
create index qse_deck_review_decisions_deck_idx
  on public.qse_deck_review_decisions(deck_id,decided_at desc);
alter table public.qse_deck_review_decisions enable row level security;
revoke all on public.qse_deck_review_decisions from public,anon,authenticated;

-- Grant to the ONE existing editor account confirmed by the owner;
-- this is a one-time identity lookup, NOT an inherited editor authorization.
do $grant$
declare v_id uuid; v_matches integer;
begin
 select count(*) into v_matches
 from public.qse_editor_admins e
 join auth.users a on a.id=e.user_id
 join qse_v3.player_profiles p on p.user_id=e.user_id
 where a.deleted_at is null and (
 left(split_part(a.email,'@',1),1)
 ||repeat('*',greatest(length(split_part(a.email,'@',1))-2,3))
 ||case when length(split_part(a.email,'@',1))>1 then right(split_part(a.email,'@',1),1) else '' end
 ||'@'||split_part(a.email,'@',2))='a********6@gmail.com';
 if v_matches<>1 or (select count(*) from public.qse_editor_admins)<>1 then
   raise exception 'confirmed_reviewer_identity_not_unique' using errcode='23514';
 end if;
 select e.user_id into strict v_id from public.qse_editor_admins e
 join auth.users a on a.id=e.user_id
 where a.deleted_at is null and (
 left(split_part(a.email,'@',1),1)
 ||repeat('*',greatest(length(split_part(a.email,'@',1))-2,3))
 ||case when length(split_part(a.email,'@',1))>1 then right(split_part(a.email,'@',1),1) else '' end
 ||'@'||split_part(a.email,'@',2))='a********6@gmail.com';
 insert into public.qse_deck_reviewers(user_id) values(v_id);
end
$grant$;

CREATE OR REPLACE FUNCTION qse_v3.deck_review_is_moderator()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select auth.uid() is not null and exists (
 select 1 from public.qse_deck_reviewers r where r.user_id=auth.uid())
$function$;

revoke all on function qse_v3.deck_review_is_moderator() from public,anon,authenticated;
grant execute on function qse_v3.deck_review_is_moderator() to authenticated;

CREATE OR REPLACE FUNCTION qse_v3.deck_review_pending_asset(p_path text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select coalesce(qse_v3.deck_review_is_moderator(),false) and exists (
 select 1 from public.qse_creator_decks d
 where d.status='pending_review' and (
  (d.cover_mode='upload'
   and d.cover_image_path=d.owner_id::text||'/'||d.id::text||'/deck_cover.png'
   and p_path=d.cover_image_path)
  or exists (
   select 1 from public.qse_creator_cards c
   where c.deck_id=d.id and c.owner_id=d.owner_id
    and p_path in (
      c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png',
      c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png'
    ))
 ))
$function$;

revoke all on function qse_v3.deck_review_pending_asset(text) from public,anon,authenticated;
grant execute on function qse_v3.deck_review_pending_asset(text) to authenticated;

create policy qse_deck_pending_review_assets_read on storage.objects
as permissive for select to authenticated
using (bucket_id='qse-deck-originals'
  and qse_v3.deck_review_pending_asset(name));
