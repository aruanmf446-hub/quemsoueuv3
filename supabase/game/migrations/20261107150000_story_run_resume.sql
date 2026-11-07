-- Continuidade da partida jogável. Não altera autenticação, economia ou provas de recompensa.
begin;
create or replace function qse_v3.valid_story_run(s jsonb)
returns boolean language plpgsql immutable set search_path='' as $$
declare k text; a jsonb; v jsonb; n numeric;
begin
 if jsonb_typeof(s) is distinct from 'object' or octet_length(s::text)>65536 then return false; end if;
 if not s ?& array['schema_version','run_id','change_id','phase','checkpoint','position','health','charges','defeated','collected','tasks','task_steps','elapsed','lessons','checkpoint_state','boss_defeated','boss_health'] then return false; end if;
 if (s-array['schema_version','run_id','change_id','phase','checkpoint','position','health','charges','defeated','collected','tasks','task_steps','elapsed','lessons','checkpoint_state','boss_defeated','boss_health'])<>'{}'::jsonb then return false; end if;
 foreach k in array array['schema_version','phase','checkpoint','health','elapsed','boss_health'] loop
  if jsonb_typeof(s->k) is distinct from 'number' then return false; end if;
  n=(s->>k)::numeric;
  if k<>'elapsed' and n<>trunc(n) then return false; end if;
 end loop;
 if (s->>'schema_version')::int<>1 or (s->>'phase')::int not between 1 and 10 or (s->>'checkpoint')::int not between -1 and 6 or (s->>'health')::int not between 1 and 3 or (s->>'elapsed')::numeric not between 0 and 10000000 or (s->>'boss_health')::int not between 0 and 20 then return false; end if;
 if jsonb_typeof(s->'boss_defeated') is distinct from 'boolean' then return false; end if;
 foreach k in array array['run_id','change_id'] loop
  if jsonb_typeof(s->k) is distinct from 'string' or s->>k !~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' then return false; end if;
 end loop;
 if jsonb_typeof(s->'position') is distinct from 'array' or jsonb_array_length(s->'position')<>2 then return false; end if;
 if jsonb_typeof(s->'position'->0) is distinct from 'number' or jsonb_typeof(s->'position'->1) is distinct from 'number' then return false; end if;
 if (s->'position'->>0)::numeric not between -32 and 1500 or (s->'position'->>1)::numeric not between -16 and 64 then return false; end if;
 a=s->'charges';
 if jsonb_typeof(a) is distinct from 'object' or not a ?& array['attack','defense','amber','dash','rupture'] or (a-array['attack','defense','amber','dash','rupture'])<>'{}'::jsonb then return false; end if;
 foreach k in array array['attack','defense','amber','dash','rupture'] loop
  if jsonb_typeof(a->k) is distinct from 'number' then return false; end if;
  n=(a->>k)::numeric;
  if n<>trunc(n) or n not between 0 and 3 then return false; end if;
 end loop;
 if ((s->>'phase')::int<3 and (a->>'amber')::int<>0) or ((s->>'phase')::int<4 and (a->>'dash')::int<>0) or ((s->>'phase')::int<5 and (a->>'rupture')::int<>0) then return false; end if;
 if jsonb_typeof(s->'checkpoint_state') is distinct from 'object' then return false; end if;
 foreach a in array array[s,s->'checkpoint_state'] loop
  foreach k in array array['defeated','collected','tasks'] loop
   if jsonb_typeof(a->k) is distinct from 'array' or jsonb_array_length(a->k)>512 then return false; end if;
   for v in select value from jsonb_array_elements(a->k) loop
    if jsonb_typeof(v) is distinct from 'string' or length(v#>>'{}')>96 then return false; end if;
   end loop;
  end loop;
  if jsonb_typeof(a->'task_steps') is distinct from 'object' or (select count(*) from jsonb_object_keys(a->'task_steps'))>2 then return false; end if;
  for v in select value from jsonb_each(a->'task_steps') loop
   if jsonb_typeof(v) is distinct from 'number' or (v#>>'{}')::numeric not between 0 and 2 or (v#>>'{}')::numeric<>trunc((v#>>'{}')::numeric) then return false; end if;
  end loop;
 end loop;
 if jsonb_typeof(s->'lessons') is distinct from 'array' or jsonb_array_length(s->'lessons')>6 then return false; end if;
 for v in select value from jsonb_array_elements(s->'lessons') loop
  if jsonb_typeof(v) is distinct from 'string' or v#>>'{}' not in ('attack','defense','task','amber','dash','rupture') then return false; end if;
 end loop;
 return true;
exception when others then return false;
end;
$$;
revoke all on function qse_v3.valid_story_run(jsonb) from public,anon,authenticated;
create table if not exists qse_v3.story_runs(
 user_id uuid primary key references auth.users(id) on delete cascade,
 state jsonb check (state is null or qse_v3.valid_story_run(state)),
 revision bigint not null default 0 check (revision>=0),
 updated_at timestamptz not null default now()
);
alter table qse_v3.story_runs enable row level security;
revoke all on qse_v3.story_runs from public,anon,authenticated;
create or replace function public.qse_story_run_sync(p_state jsonb default null,p_revision bigint default 0,p_completed integer default 0,p_intent text default 'save')
returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=qse_v3.require_user(); current_run qse_v3.story_runs; progress jsonb; applied boolean:=false; farther boolean:=false; same_run boolean:=false;
begin
 if p_revision is null or p_revision<0 or p_intent is null or p_intent not in ('save','start') then raise exception 'invalid_story_run' using errcode='22023'; end if;
 progress=public.qse_story_progress_sync(p_completed);
 if p_state is not null then
  if not qse_v3.valid_story_run(p_state) or (p_state->>'phase')::int>least(10,(progress->>'highest_completed')::int+1) then raise exception 'invalid_story_run' using errcode='22023'; end if;
 end if;
 insert into qse_v3.story_runs(user_id) values(owner) on conflict(user_id) do nothing;
 select * into current_run from qse_v3.story_runs where user_id=owner for update;
 if p_state is not null then
  if current_run.state is not null then
   same_run=(p_state->>'run_id')=(current_run.state->>'run_id');
   farther=((p_state->>'phase')::int,(p_state->>'checkpoint')::int,(p_state->'position'->>0)::numeric)>((current_run.state->>'phase')::int,(current_run.state->>'checkpoint')::int,(current_run.state->'position'->>0)::numeric);
  end if;
  if current_run.state is null or (p_revision=current_run.revision and (same_run or p_intent='start')) or farther then
   if current_run.state is distinct from p_state then
    update qse_v3.story_runs set state=p_state,revision=revision+1,updated_at=now() where user_id=owner returning * into current_run;
   end if;
   applied=true;
  end if;
 end if;
 return jsonb_build_object('schema_version',1,'revision',current_run.revision,'state',current_run.state,'applied',applied,'highest_completed',progress->'highest_completed');
end;
$$;
revoke all on function public.qse_story_run_sync(jsonb,bigint,integer,text) from public,anon;
grant execute on function public.qse_story_run_sync(jsonb,bigint,integer,text) to authenticated;
comment on table qse_v3.story_runs is 'Partida do Modo História: estado de combate sem valor econômico, isolado por auth.uid().';
commit;
