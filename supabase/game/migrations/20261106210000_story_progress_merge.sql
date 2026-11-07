-- Campanha jogável: continuidade entre visitante/conta/aparelhos.
-- Não concede conquistas, inventário, moeda nem phase_completions verificadas.
begin;
create table if not exists qse_v3.story_progress (
 user_id uuid primary key references auth.users(id) on delete cascade,
 highest_completed integer not null default 0 check (highest_completed between 0 and 10),
 revision bigint not null default 1,
 updated_at timestamptz not null default now()
);
alter table qse_v3.story_progress enable row level security;
revoke all on qse_v3.story_progress from public,anon,authenticated;
create or replace function public.qse_story_progress_sync(p_completed integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_uid uuid := qse_v3.require_user();
 v_legacy integer;
 v_previous integer;
 v_highest integer;
 v_revision bigint;
begin
 if p_completed is null or p_completed not between 0 and 10 then
  raise exception 'invalid_story_progress' using errcode='22023';
 end if;
 -- Conta existente: preserva todas as fases contíguas já confirmadas.
 select coalesce(min(p.ordinal)-1,10) into v_legacy from qse_v3.desert_phases p
 where not exists(select 1 from qse_v3.phase_completions c where c.user_id=v_uid and c.phase_id=p.id);
 select greatest(v_legacy,coalesce(max(p.ordinal)-1,0)) into v_legacy
 from qse_v3.campaign_progress c join qse_v3.desert_phases p on p.id=c.active_phase_id where c.user_id=v_uid;
 select highest_completed into v_previous from qse_v3.story_progress where user_id=v_uid for update;
 v_previous:=greatest(coalesce(v_previous,0),v_legacy);
 -- GREATEST no UPSERT também protege duas primeiras gravações simultâneas.
 insert into qse_v3.story_progress(user_id,highest_completed)
 values(v_uid,greatest(v_legacy,p_completed))
 on conflict(user_id) do update set
  highest_completed=greatest(story_progress.highest_completed,excluded.highest_completed),
  revision=story_progress.revision+case when excluded.highest_completed>story_progress.highest_completed then 1 else 0 end,
  updated_at=case when excluded.highest_completed>story_progress.highest_completed then now() else story_progress.updated_at end
 returning highest_completed,revision into v_highest,v_revision;
 return jsonb_build_object('schema_version',1,'highest_completed',v_highest,'previous_completed',v_previous,'revision',v_revision);
end;
$$;
revoke all on function public.qse_story_progress_sync(integer) from public,anon;
grant execute on function public.qse_story_progress_sync(integer) to authenticated;
comment on table qse_v3.story_progress is 'Continuidade da campanha; não é evidência para recompensas ou economia.';
commit;
