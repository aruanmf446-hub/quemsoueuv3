-- GAME: denúncias de jogadores. Sem banimento automático nem acesso às denúncias pelo cliente.
begin;
create table qse_v3.player_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  reason text not null check(char_length(btrim(reason)) between 3 and 280),
  status text not null default 'pending' check(status in ('pending','reviewed','dismissed')),
  created_at timestamptz not null default now(),
  check(reporter_id<>target_id)
);
create unique index player_reports_pending_unique on qse_v3.player_reports(reporter_id,target_id) where status='pending';
create index player_reports_rate_idx on qse_v3.player_reports(reporter_id,created_at);
alter table qse_v3.player_reports enable row level security;
revoke all on qse_v3.player_reports from public,anon,authenticated;

create function public.qse_player_report(p_public_id text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_actor uuid:=auth.uid(); v_target uuid; v_reason text:=btrim(coalesce(p_reason,''));
begin
  if v_actor is null then return jsonb_build_object('error','unauthorized'); end if;
  if char_length(v_reason) not between 3 and 280 then
    return jsonb_build_object('error','invalid_reason'); end if;
  select user_id into v_target from qse_v3.player_profiles
    where public_id=btrim(p_public_id);
  if v_target is null then return jsonb_build_object('error','player_not_found'); end if;
  if v_target=v_actor then return jsonb_build_object('error','cannot_report_self'); end if;
  -- Serializa envios do mesmo autor: duplicidade e limite também valem em duas abas.
  perform pg_advisory_xact_lock(hashtextextended('qse-player-report:'||v_actor::text,0));
  if exists(select 1 from qse_v3.player_reports
    where reporter_id=v_actor and target_id=v_target and status='pending') then
    return jsonb_build_object('error','already_reported'); end if;
  if (select count(*) from qse_v3.player_reports where reporter_id=v_actor
    and created_at>now()-interval '24 hours')>=10 then
    return jsonb_build_object('error','rate_limit'); end if;
  insert into qse_v3.player_reports(reporter_id,target_id,reason)
    values(v_actor,v_target,v_reason);
  return jsonb_build_object('reported',true);
end;
$function$;
revoke all on function public.qse_player_report(text,text) from public,anon,authenticated;
grant execute on function public.qse_player_report(text,text) to authenticated;
notify pgrst,'reload schema';
commit;
