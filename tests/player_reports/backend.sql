-- Executar após a migration. Todos os dados abaixo são revertidos.
begin;
do $test$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid; pub text; own text; v jsonb;
begin
 insert into auth.users(id) values(a),(b);
 -- O hook de criação pode ser diferido; perfis independentes só nesta transação revertida.
 insert into qse_v3.player_profiles(user_id) values(a),(b) on conflict do nothing;
 select public_id into pub from qse_v3.player_profiles where user_id=b;
 select public_id into own from qse_v3.player_profiles where user_id=a;
 perform set_config('request.jwt.claim.sub','',true);
 assert public.qse_player_report(pub,'Motivo QA')->>'error'='unauthorized';
 perform set_config('request.jwt.claim.sub',a::text,true);
 assert public.qse_player_report(pub,' x ')->>'error'='invalid_reason';
 assert public.qse_player_report(pub,repeat('x',281))->>'error'='invalid_reason';
 assert public.qse_player_report(own,'Motivo QA')->>'error'='cannot_report_self';
 assert public.qse_player_report('inexistente','Motivo QA')->>'error'='player_not_found';
 assert public.qse_player_report(pub,'  Motivo QA  ')->>'reported'='true';
 assert (select reason='Motivo QA' from qse_v3.player_reports where reporter_id=a and target_id=b);
 assert public.qse_player_report(pub,'Segundo envio')->>'error'='already_reported';
 assert (select count(*)=1 from qse_v3.player_reports where reporter_id=a and target_id=b);
 for i in 1..10 loop
   c:=gen_random_uuid(); insert into auth.users(id) values(c);
   insert into qse_v3.player_profiles(user_id) values(c) on conflict do nothing;
   select public_id into pub from qse_v3.player_profiles where user_id=c;
   v:=public.qse_player_report(pub,'Motivo QA limite');
   if i<10 then assert v->>'reported'='true';
   else assert v->>'error'='rate_limit'; end if;
 end loop;
 assert not has_table_privilege('authenticated','qse_v3.player_reports','SELECT');
 assert not has_table_privilege('authenticated','qse_v3.player_reports','INSERT');
 assert not has_table_privilege('authenticated','qse_v3.player_reports','UPDATE');
 assert not has_table_privilege('authenticated','qse_v3.player_reports','DELETE');
 assert not has_table_privilege('authenticated','qse_v3.player_reports','TRUNCATE');
 assert not has_function_privilege('anon','public.qse_player_report(text,text)','EXECUTE');
 assert has_function_privilege('authenticated','public.qse_player_report(text,text)','EXECUTE');
 assert (select relrowsecurity from pg_class where oid='qse_v3.player_reports'::regclass);
end;
$test$;
select jsonb_build_object('passed',true,'transaction','rollback','areas',array['auth','reason','self','missing','stored','duplicate','rate','acl','rls']) as result;
rollback;
