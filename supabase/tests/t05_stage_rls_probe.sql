-- DIAGNOSTIC ONLY: isolated project ifomrkzmxgwwjapoeklo. NEVER deploy to production.
begin;
create function public.qse_t05_rls_probe(p_target uuid,p_mode text) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  if p_mode='read' then
    return jsonb_build_object('role',current_user,'subject',auth.uid(),
      'wallet_rows',(select count(*) from qse_v3.wallets where user_id=p_target),
      'profile_rows',(select count(*) from qse_v3.player_profiles where user_id=p_target),
      'unlock_rows',(select count(*) from qse_v3.character_unlocks where user_id=p_target));
  elsif p_mode='write' then
    update qse_v3.wallets set coins=999999 where user_id=p_target;
    return jsonb_build_object('unexpected_write',true);
  end if;
  raise exception 'unknown_probe';
end $$;
revoke all on function public.qse_t05_rls_probe(uuid,text) from public,anon,authenticated;
grant execute on function public.qse_t05_rls_probe(uuid,text) to authenticated;
commit;
