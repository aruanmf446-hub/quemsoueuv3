alter table public.qse_creator_decks add column if not exists published_at timestamptz;
create or replace function qse_v3.t24_set_published_at()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if tg_op='INSERT' then
   if new.status='published' then new.published_at:=now(); else new.published_at:=null; end if;
 elsif new.status='published' and old.status is distinct from 'published' then
   new.published_at:=now();
 else
   new.published_at:=old.published_at;
 end if;
 return new;
end;
$$;
drop trigger if exists qse_creator_decks_publish_timestamp on public.qse_creator_decks;
create trigger qse_creator_decks_publish_timestamp before insert or update on public.qse_creator_decks for each row execute function qse_v3.t24_set_published_at();
revoke all on function qse_v3.t24_set_published_at() from public,anon,authenticated;
