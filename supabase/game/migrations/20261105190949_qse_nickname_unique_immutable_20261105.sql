-- GAME: migration 20261105190949, executada em producao no GAME.
-- Base: player_profiles ja existe; sem exclusao de contas, inventario ou progresso.
-- Normalizacao: btrim ASCII + NFC + lower da collation PostgreSQL.
CREATE OR REPLACE FUNCTION qse_v3.nickname_key(p_value text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case when p_value is null then null
  else lower(normalize(btrim(p_value), NFC)) end
$function$
;
CREATE OR REPLACE FUNCTION qse_v3.nickname_valid(p_value text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select coalesce(
    char_length(btrim(p_value)) between 3 and 24
    and btrim(p_value) !~ '[[:cntrl:]]'
    and btrim(p_value) !~ U&'[\00AD\034F\061C\115F\1160\17B4-\17B5\180E\200B-\200F\202A-\202E\2060-\206F\2800\3164\FEFF\FFA0]'
    and btrim(p_value) !~ U&'[\00A0\1680\2000-\200A\202F\205F\3000]'
    and qse_v3.nickname_key(p_value) not in ('jogador local','sem nickname','você','<null>','null','guest','local player','anonymous'), false)
$function$
;

create unique index if not exists qse_player_profiles_nickname_key_unique
 on qse_v3.player_profiles(qse_v3.nickname_key(nickname)) where nickname is not null;
do $$
begin
 if not exists (select 1 from pg_constraint
   where conrelid='qse_v3.player_profiles'::regclass and conname='player_profiles_nickname_valid_v2') then
   alter table qse_v3.player_profiles add constraint player_profiles_nickname_valid_v2
     check(nickname is null or qse_v3.nickname_valid(nickname)) not valid;
 end if;
end $$;
alter table qse_v3.player_profiles validate constraint player_profiles_nickname_valid_v2;
CREATE OR REPLACE FUNCTION qse_v3.nickname_write_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if TG_OP = 'UPDATE' then
    if OLD.nickname is not null and NEW.nickname is distinct from OLD.nickname then
      raise exception 'nickname_locked' using errcode='P0001';
    end if;
  end if;
  if NEW.nickname is not null then
    if not qse_v3.nickname_valid(NEW.nickname) then
      raise exception 'invalid_nickname' using errcode='P0001';
    end if;
    if TG_OP = 'INSERT' then
      NEW.nickname := normalize(btrim(NEW.nickname), NFC);
    elsif OLD.nickname is null then
      NEW.nickname := normalize(btrim(NEW.nickname), NFC);
    end if;
  end if;
  return NEW;
end $function$
;

do $$
begin
 if not exists(select 1 from pg_trigger where tgrelid='qse_v3.player_profiles'::regclass
   and tgname='qse_player_nickname_first_write') then
   create trigger qse_player_nickname_first_write
     before insert or update of nickname on qse_v3.player_profiles
     for each row execute function qse_v3.nickname_write_guard();
 end if;
end $$;
CREATE OR REPLACE FUNCTION qse_v3.public_fragment(owner uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object('user_id',p.user_id,'public_id',p.public_id,'nickname',p.nickname,
    'level',s.level,'equipped_character_id',l.equipped_character_id)
  from qse_v3.player_profiles p join qse_v3.player_loadout l using(user_id)
    join qse_v3.player_statistics s using(user_id) where p.user_id=owner
$function$
;
CREATE OR REPLACE FUNCTION public.qse_profile_update(p_nickname text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner uuid := qse_v3.require_user(); stored text; clean text;
begin
  perform qse_v3.ensure_player(owner);
  if not qse_v3.nickname_valid(p_nickname) then
    return jsonb_build_object('error','invalid_nickname','error_code','invalid_nickname');
  end if;
  clean := normalize(btrim(p_nickname), NFC);
  select nickname into stored from qse_v3.player_profiles where user_id=owner for update;
  if stored is not null then
    if qse_v3.nickname_key(stored)=qse_v3.nickname_key(clean) then
      return public.qse_profile_self();
    end if;
    return jsonb_build_object('error','nickname_locked','error_code','nickname_locked');
  end if;
  begin
    update qse_v3.player_profiles set nickname=clean,updated_at=now()
      where user_id=owner and nickname is null;
  exception when unique_violation then
    return jsonb_build_object('error','nickname_taken','error_code','nickname_taken');
  end;
  return public.qse_profile_self();
end $function$
;
CREATE OR REPLACE FUNCTION public.qse_find_players(p_term text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner uuid := qse_v3.require_user(); result jsonb;
begin
  if p_term is null or char_length(btrim(p_term)) not between 2 and 64 then
    return jsonb_build_object('error','invalid_search'); end if;
  select coalesce(jsonb_agg(qse_v3.public_fragment(x.user_id)),'[]'::jsonb) into result
  from (select p.user_id from qse_v3.player_profiles p
    join qse_v3.account_preferences a using(user_id)
    where p.user_id<>owner and a.discoverable and p.nickname is not null
      and (lower(p.public_id)=lower(btrim(p_term))
        or position(lower(btrim(p_term)) in lower(p.nickname))>0)
    order by p.public_id limit 20) x;
  return jsonb_build_object('players',result);
end $function$
;
CREATE OR REPLACE FUNCTION public.qse_profile_public(p_public_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner uuid := qse_v3.require_user(); target uuid;
begin
  select p.user_id into target from qse_v3.player_profiles p
  join qse_v3.account_preferences a using(user_id)
  where p.public_id=p_public_id and (p.user_id=owner or
    (p.nickname is not null and (a.discoverable or exists(
      select 1 from qse_v3.friendships f
      where f.user_low=least(owner,p.user_id) and f.user_high=greatest(owner,p.user_id)))));
  return coalesce(qse_v3.public_fragment(target),'{}'::jsonb);
end $function$
;

revoke all on function qse_v3.nickname_key(text),qse_v3.nickname_valid(text),
 qse_v3.nickname_write_guard() from public,anon,authenticated;
