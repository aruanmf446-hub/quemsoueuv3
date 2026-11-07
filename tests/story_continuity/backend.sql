-- Executar em transação e finalizar com ROLLBACK. Usa dois UIDs existentes sem expô-los.
begin;
do $test$
declare
 ids uuid[];
 a jsonb;
 b jsonb;
begin
 select array_agg(id) into ids from (
  select u.id from auth.users u
  where not exists(select 1 from qse_v3.phase_completions c where c.user_id=u.id)
    and not exists(select 1 from qse_v3.campaign_progress c join qse_v3.desert_phases p on p.id=c.active_phase_id where c.user_id=u.id and p.ordinal>1)
  order by u.created_at desc limit 2
 ) sample;
 if coalesce(array_length(ids,1),0)<2 then raise exception 'Two existing zero-progress test identities required';end if;
 delete from qse_v3.story_progress where user_id=any(ids);
 perform set_config('request.jwt.claim.sub',ids[1]::text,true);
 a:=public.qse_story_progress_sync(2);
 if (a->>'highest_completed')::int<>2 then raise exception 'Local phase transfer failed';end if;
 a:=public.qse_story_progress_sync(5);
 if (a->>'highest_completed')::int<>5 then raise exception 'Higher guest progress lost';end if;
 b:=public.qse_story_progress_sync(2);
 if (b->>'highest_completed')::int<>5 or (b->>'previous_completed')::int<>5 then raise exception 'Cloud advance rolled back';end if;
 if b->>'revision'<>a->>'revision' then raise exception 'Noop incorrectly advances revision';end if;
 perform set_config('request.jwt.claim.sub',ids[2]::text,true);
 b:=public.qse_story_progress_sync(0);
 if (b->>'highest_completed')::int<>0 then raise exception 'Another account leaked progress';end if;
 b:=public.qse_story_progress_sync(1);
 if (b->>'highest_completed')::int<>1 then raise exception 'Second owner cannot save';end if;
 perform set_config('request.jwt.claim.sub',ids[1]::text,true);
 a:=public.qse_story_progress_sync(0);
 if (a->>'highest_completed')::int<>5 then raise exception 'Switching owners loses progress';end if;
 begin
  perform public.qse_story_progress_sync(11);
  raise exception 'Out-of-range progress accepted';
 exception when invalid_parameter_value then null;end;
 if has_function_privilege('anon','public.qse_story_progress_sync(integer)','execute') then raise exception 'Anonymous RPC access granted';end if;
 if has_table_privilege('authenticated','qse_v3.story_progress','select') or has_table_privilege('authenticated','qse_v3.story_progress','update') then raise exception 'Direct table access granted';end if;
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
 begin
  perform public.qse_story_progress_sync(5);
  raise exception 'Missing authentication accepted';
 exception when insufficient_privilege then null;end;
end;
$test$;
select 'story_backend_checks_passed_rolled_back' as result;
rollback;
