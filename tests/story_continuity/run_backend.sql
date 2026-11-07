-- Execute dentro da transação da migration e termine com ROLLBACK; nunca deixa partidas de QA.
do $$
declare ids uuid[]; s jsonb; r jsonb; v bigint; before_user_count bigint;
begin
 select array_agg(id) into ids from (select id from auth.users order by id limit 2) u;
 if coalesce(array_length(ids,1),0)<2 then raise exception 'Two existing accounts required for rollback-only isolation check'; end if;
 if has_function_privilege('anon','public.qse_story_run_sync(jsonb,bigint,integer,text)','execute') or has_table_privilege('authenticated','qse_v3.story_runs','select') then raise exception 'run access must be private'; end if;
 perform set_config('request.jwt.claim.sub',ids[1]::text,true);
 s=jsonb_build_object('schema_version',1,'run_id',gen_random_uuid()::text,'change_id',gen_random_uuid()::text,'phase',5,'checkpoint',6,'position',jsonb_build_array(1300,0),'health',2,'charges','{"attack":2,"defense":0,"amber":3,"dash":1,"rupture":2}'::jsonb,'defeated','["p05.cactus.02"]'::jsonb,'collected','["p05.supply.00"]'::jsonb,'tasks','["p05.task.0","p05.task.1"]'::jsonb,'task_steps','{"p05.task.0":2}'::jsonb,'elapsed',245,'lessons','["amber","dash","rupture"]'::jsonb,'checkpoint_state','{"defeated":[],"collected":[],"tasks":[],"task_steps":{}}'::jsonb,'boss_defeated',false,'boss_health',20);
 if not qse_v3.valid_story_run(s) then raise exception 'valid full run rejected'; end if;
 delete from qse_v3.story_runs where user_id=ids[1]; -- Restored by the encompassing rollback.
 r=public.qse_story_run_sync(s,0,4,'start');v=(r->>'revision')::bigint;
 if not (r->>'applied')::boolean or r->'state'<>s then raise exception 'initial full save mismatch'; end if;
 r=public.qse_story_run_sync(null,0,4,'save');
 if r->'state'<>s or (r->'state'->>'checkpoint')::int<>6 then raise exception 'fresh device lost checkpoint 7 / inventory'; end if;
 s=jsonb_set(s,'{change_id}',to_jsonb(gen_random_uuid()::text));
 s=jsonb_set(s,'{charges,attack}','0'::jsonb);
 r=public.qse_story_run_sync(s,v,4,'save');
 if (r->'state'->'charges'->>'attack')::int<>0 then raise exception 'spent charge resurrected'; end if;
 r=public.qse_story_run_sync(jsonb_set(s,'{charges,attack}','3'::jsonb),v,4,'save');
 if (r->>'applied')::boolean or (r->'state'->'charges'->>'attack')::int<>0 then raise exception 'stale device resurrected ammunition'; end if;
 s=jsonb_set(s,'{change_id}',to_jsonb(gen_random_uuid()::text));s=jsonb_set(s,'{position,0}','1350'::jsonb);
 r=public.qse_story_run_sync(s,0,4,'save');
 if not (r->>'applied')::boolean then raise exception 'offline farther progress lost'; end if;
 begin
  perform public.qse_story_run_sync(jsonb_set(s,'{charges,attack}','99'::jsonb),0,4,'save');
  raise exception 'invalid charges accepted';
 exception when sqlstate '22023' then null; end;
 perform set_config('request.jwt.claim.sub',ids[2]::text,true);
 select count(*) into before_user_count from qse_v3.story_runs where user_id=ids[2];
 r=public.qse_story_run_sync(null,0,0,'save');
 if r->'state'=s then raise exception 'cross-account run leaked'; end if;
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
 begin
  perform public.qse_story_run_sync();raise exception 'anonymous run read accepted';
 exception when insufficient_privilege then null; end;
end;
$$;
select 'STORY_RUN_BACKEND_PASS' as result;
