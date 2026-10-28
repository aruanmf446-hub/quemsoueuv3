begin;
create function public.qse_profile_self() returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); result jsonb;
begin
  perform qse_v3.ensure_player(owner);
  select qse_v3.public_fragment(owner) || jsonb_build_object('experience',s.experience::text,'statistics',s.statistics,
    'discoverable',a.discoverable) into result from qse_v3.player_statistics s join qse_v3.account_preferences a using(user_id) where s.user_id=owner;
  return result;
end $$;
create function public.qse_profile_update(p_nickname text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user();
begin
  perform qse_v3.ensure_player(owner);
  if p_nickname is null or char_length(btrim(p_nickname)) not between 3 and 24 or p_nickname ~ '[[:cntrl:]]' then
    return jsonb_build_object('error','invalid_nickname'); end if;
  update qse_v3.player_profiles set nickname=btrim(p_nickname),updated_at=now() where user_id=owner;
  return public.qse_profile_self();
end $$;
create function public.qse_account_preferences(p_discoverable boolean) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user();
begin
  perform qse_v3.ensure_player(owner);
  if p_discoverable is null then return jsonb_build_object('error','invalid_contract'); end if;
  update qse_v3.account_preferences set discoverable=p_discoverable,updated_at=now() where user_id=owner;
  return jsonb_build_object('discoverable',p_discoverable);
end $$;
create function public.qse_profile_public(p_public_id text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); target uuid;
begin
  select p.user_id into target from qse_v3.player_profiles p join qse_v3.account_preferences a using(user_id)
    where p.public_id=p_public_id and (p.user_id=owner or a.discoverable or exists
      (select 1 from qse_v3.friendships f where f.user_low=least(owner,p.user_id) and f.user_high=greatest(owner,p.user_id)));
  return coalesce(qse_v3.public_fragment(target),'{}'::jsonb);
end $$;
create function public.qse_find_players(p_term text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); result jsonb;
begin
  if p_term is null or char_length(btrim(p_term)) not between 2 and 64 then return jsonb_build_object('error','invalid_search'); end if;
  select coalesce(jsonb_agg(qse_v3.public_fragment(x.user_id)),'[]'::jsonb) into result from
    (select p.user_id from qse_v3.player_profiles p join qse_v3.account_preferences a using(user_id)
     where p.user_id<>owner and a.discoverable and (lower(p.public_id)=lower(btrim(p_term))
       or position(lower(btrim(p_term)) in lower(p.nickname))>0)
     order by p.public_id limit 20) x;
  return jsonb_build_object('players',result);
end $$;
create function public.qse_friends() returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user();
begin
  perform qse_v3.ensure_player(owner);
  return jsonb_build_object(
    'friends',coalesce((select jsonb_agg(qse_v3.public_fragment(case when f.user_low=owner then f.user_high else f.user_low end) order by f.created_at)
      from qse_v3.friendships f where owner in (f.user_low,f.user_high)),'[]'::jsonb),
    'incoming',coalesce((select jsonb_agg(qse_v3.public_fragment(r.sender_id) order by r.created_at) from qse_v3.friend_requests r where r.recipient_id=owner),'[]'::jsonb),
    'outgoing',coalesce((select jsonb_agg(qse_v3.public_fragment(r.recipient_id) order by r.created_at) from qse_v3.friend_requests r where r.sender_id=owner),'[]'::jsonb));
end $$;
create function public.qse_friend_action(p_action text,p_target uuid,p_request_id uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); prior qse_v3.processed_requests%rowtype;
  command jsonb := jsonb_build_object('action',p_action,'target',p_target); response jsonb; affected integer;
begin
  perform qse_v3.ensure_player(owner);
  if p_request_id is null or p_target is null or owner=p_target or p_action not in ('send','accept','decline','cancel','remove') or p_action is null then
    return jsonb_build_object('error','invalid_friend_request'); end if;
  -- Serializa por dono da chave de idempotência e por par de usuários, inclusive pedidos cruzados.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner::text || ':friend-action',0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(least(owner,p_target)::text || greatest(owner,p_target)::text,0));
  select * into prior from qse_v3.processed_requests where user_id=owner and domain='friends' and request_id=p_request_id;
  if found then
    if prior.request<>command then return jsonb_build_object('error','idempotency_conflict'); end if;
    return prior.response;
  end if;
  if not exists(select 1 from qse_v3.player_profiles where user_id=p_target) then return jsonb_build_object('error','player_not_found'); end if;
  if p_action='send' then
    if not exists(select 1 from qse_v3.account_preferences where user_id=p_target and discoverable) then return jsonb_build_object('error','player_not_found'); end if;
    if exists(select 1 from qse_v3.friendships where user_low=least(owner,p_target) and user_high=greatest(owner,p_target)) then
      response := jsonb_build_object('status','noop');
    elsif exists(select 1 from qse_v3.friend_requests where sender_id=p_target and recipient_id=owner) then
      return jsonb_build_object('error','incoming_request_exists');
    elsif (select count(*) from qse_v3.friend_requests where sender_id=owner)>=100 then
      return jsonb_build_object('error','rate_limit');
    else
      insert into qse_v3.friend_requests values(owner,p_target,now()) on conflict do nothing;
      response := jsonb_build_object('status','applied');
    end if;
  elsif p_action in ('accept','decline') then
    delete from qse_v3.friend_requests where sender_id=p_target and recipient_id=owner;
    get diagnostics affected=row_count;
    if affected=0 then return jsonb_build_object('error','request_not_found'); end if;
    if p_action='accept' then
      insert into qse_v3.friendships values(least(owner,p_target),greatest(owner,p_target),now()) on conflict do nothing;
      delete from qse_v3.friend_requests where sender_id=owner and recipient_id=p_target;
    end if;
    response := jsonb_build_object('status','applied');
  elsif p_action='cancel' then
    delete from qse_v3.friend_requests where sender_id=owner and recipient_id=p_target;
    response := jsonb_build_object('status','applied');
  else
    delete from qse_v3.friendships where user_low=least(owner,p_target) and user_high=greatest(owner,p_target);
    response := jsonb_build_object('status','applied');
  end if;
  insert into qse_v3.processed_requests values(owner,p_request_id,'friends',command,response);
  return response;
end $$;

create function public.qse_wallet_history(p_before text default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); result jsonb; next_cursor text;
begin
  if p_before is not null and p_before !~ '^[1-9][0-9]{0,18}$' then return jsonb_build_object('error','invalid_cursor'); end if;
  if p_before is not null and p_before::numeric > 9223372036854775807::numeric then
    return jsonb_build_object('error','invalid_cursor');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('transaction_id',x.transaction_id,'sequence',x.sequence::text,
    'currency',x.currency,'amount',x.amount::text,'balance_after',x.balance_after::text,'reason',x.reason,'created_at',x.created_at) order by x.sequence desc),'[]'::jsonb),
    case when count(*)=20 then min(x.sequence)::text end into result,next_cursor from
    (select * from qse_v3.wallet_transactions where user_id=owner and (p_before is null or sequence<p_before::bigint) order by sequence desc limit 20) x;
  return jsonb_build_object('transactions',result,'next_cursor',next_cursor);
end $$;
create function public.qse_wallet() returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); result jsonb;
begin
  perform qse_v3.ensure_player(owner);
  select jsonb_build_object('coins',coins::text,'gems',gems::text,'revision',revision::text) into result from qse_v3.wallets where user_id=owner;
  return result || public.qse_wallet_history();
end $$;
-- Não é uma RPC de cliente. A função fica no schema privado e só service_role tem EXECUTE.
create function qse_v3.post_wallet_entry(p_owner uuid,p_key uuid,p_currency text,p_amount bigint,p_reason text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare prior qse_v3.wallet_transactions%rowtype; current_wallet qse_v3.wallets%rowtype; next_balance bigint; transaction uuid;
begin
  if p_key is null or p_owner is null or p_currency is null or p_amount is null or p_amount=0 or p_currency not in ('coins','gems')
    or p_reason is null or char_length(p_reason) not between 1 and 120 then raise exception 'invalid_ledger_entry'; end if;
  select * into current_wallet from qse_v3.wallets where user_id=p_owner for update;
  if not found then raise exception 'wallet_not_found'; end if;
  select * into prior from qse_v3.wallet_transactions where user_id=p_owner and idempotency_key=p_key;
  if found then
    if prior.currency<>p_currency or prior.amount<>p_amount or prior.reason<>p_reason then raise exception 'idempotency_conflict'; end if;
    return jsonb_build_object('transaction_id',prior.transaction_id,'balance_after',prior.balance_after::text);
  end if;
  next_balance := case p_currency when 'coins' then current_wallet.coins else current_wallet.gems end + p_amount;
  if next_balance<0 then raise exception 'insufficient_funds'; end if;
  update qse_v3.wallets set coins=case when p_currency='coins' then next_balance else coins end,
    gems=case when p_currency='gems' then next_balance else gems end,revision=revision+1 where user_id=p_owner;
  insert into qse_v3.wallet_transactions(user_id,idempotency_key,currency,amount,balance_after,reason)
    values(p_owner,p_key,p_currency,p_amount,next_balance,p_reason) returning transaction_id into transaction;
  return jsonb_build_object('transaction_id',transaction,'balance_after',next_balance::text);
end $$;
revoke all on function qse_v3.post_wallet_entry(uuid,uuid,text,bigint,text) from public,anon,authenticated;
grant execute on function qse_v3.post_wallet_entry(uuid,uuid,text,bigint,text) to service_role;

create function public.qse_progression_snapshot() returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user();
begin perform qse_v3.ensure_player(owner); return qse_v3.snapshot(owner); end $$;
create function public.qse_progression_command(p_request jsonb) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); progress qse_v3.campaign_progress%rowtype;
  prior qse_v3.processed_requests%rowtype; phase qse_v3.desert_phases%rowtype;
  proof qse_v3.completion_evidence%rowtype; op jsonb; v_request_id uuid; completed integer;
  outcome text := 'applied'; code text; response jsonb; operation_type text;
begin
  perform qse_v3.ensure_player(owner);
  if jsonb_typeof(p_request)<>'object' or p_request is null or
     not p_request ?& array['protocol_version','rules_version','request_id','expected_revision','operation'] or
     (p_request - array['protocol_version','rules_version','request_id','expected_revision','operation']) <> '{}'::jsonb or
     p_request->'protocol_version' is distinct from '2'::jsonb or
     p_request->>'rules_version' is distinct from 'desert_progression_2.0.0' or
     jsonb_typeof(p_request->'request_id') is distinct from 'string' or
     jsonb_typeof(p_request->'expected_revision') is distinct from 'number' then
    return jsonb_build_object('error','invalid_contract');
  end if;
  if (p_request->>'expected_revision')::numeric<0 or (p_request->>'expected_revision')::numeric>9007199254740991
    or trunc((p_request->>'expected_revision')::numeric)<>(p_request->>'expected_revision')::numeric then
    return jsonb_build_object('error','invalid_contract'); end if;
  begin v_request_id := (p_request->>'request_id')::uuid; exception when invalid_text_representation then return jsonb_build_object('error','invalid_contract'); end;
  if v_request_id is null then return jsonb_build_object('error','invalid_contract'); end if;
  op := p_request->'operation'; operation_type := op->>'type';
  if jsonb_typeof(op)<>'object' or operation_type is null then return jsonb_build_object('error','invalid_contract'); end if;
  if (operation_type='equip_character' and (not op ?& array['type','character_id'] or (op-array['type','character_id'])<>'{}'::jsonb)) or
     (operation_type='start_phase' and (not op ?& array['type','phase_id'] or (op-array['type','phase_id'])<>'{}'::jsonb)) or
     (operation_type='record_checkpoint' and (not op ?& array['type','phase_id','checkpoint_id'] or (op-array['type','phase_id','checkpoint_id'])<>'{}'::jsonb)) or
     (operation_type='complete_phase' and (not op ?& array['type','phase_id','attempt_id','evidence_id'] or (op-array['type','phase_id','attempt_id','evidence_id'])<>'{}'::jsonb)) or
     operation_type not in ('equip_character','start_phase','record_checkpoint','complete_phase') then return jsonb_build_object('error','invalid_contract'); end if;
  if (operation_type='equip_character' and (jsonb_typeof(op->'character_id') is distinct from 'string' or (op->>'character_id') !~ '^[a-z][a-z0-9_]*$')) or
     (operation_type<>'equip_character' and jsonb_typeof(op->'phase_id') is distinct from 'string') or
     (operation_type='record_checkpoint' and jsonb_typeof(op->'checkpoint_id') is distinct from 'string') or
     (operation_type='complete_phase' and (jsonb_typeof(op->'attempt_id') is distinct from 'string' or jsonb_typeof(op->'evidence_id') is distinct from 'string')) then
    return jsonb_build_object('error','invalid_contract'); end if;
  select * into progress from qse_v3.campaign_progress where user_id=owner for update;
  select * into prior from qse_v3.processed_requests where user_id=owner and domain='progression' and processed_requests.request_id=v_request_id;
  if found and prior.request=p_request then return prior.response; end if;
  if found then outcome:='rejected'; code:='idempotency_conflict';
  elsif progress.revision<>(p_request->>'expected_revision')::numeric::bigint then outcome:='conflict'; code:='revision_conflict';
  elsif operation_type='equip_character' then
    if not exists(select 1 from qse_v3.character_unlocks where user_id=owner and character_id=op->>'character_id') then outcome:='rejected'; code:='locked_character';
    elsif exists(select 1 from qse_v3.player_loadout where user_id=owner and equipped_character_id=op->>'character_id') then outcome:='noop';
    else update qse_v3.player_loadout set equipped_character_id=op->>'character_id',updated_at=now() where user_id=owner; end if;
  else
    select count(*) into completed from qse_v3.phase_completions where user_id=owner;
    select * into phase from qse_v3.desert_phases where id=op->>'phase_id';
    if not found then outcome:='rejected'; code:='invalid_phase';
    elsif phase.ordinal>completed+1 then outcome:='rejected'; code:='phase_locked';
    elsif operation_type='start_phase' then
      if progress.active_phase_id=phase.id then outcome:='noop';
      else update qse_v3.campaign_progress set active_phase_id=phase.id,checkpoint_id=null where user_id=owner; end if;
    elsif operation_type='complete_phase' and phase.ordinal<=completed then outcome:='noop';
    elsif progress.active_phase_id is distinct from phase.id then outcome:='rejected'; code:='phase_not_started';
    elsif operation_type='record_checkpoint' then
      if coalesce(op->>'checkpoint_id','') <> all(phase.checkpoint_ids) then outcome:='rejected'; code:='invalid_checkpoint';
      elsif progress.checkpoint_id=op->>'checkpoint_id' then outcome:='noop';
      else update qse_v3.campaign_progress set checkpoint_id=op->>'checkpoint_id' where user_id=owner; end if;
    else
      begin
        select * into proof from qse_v3.completion_evidence where evidence_id=(op->>'evidence_id')::uuid
          and attempt_id=(op->>'attempt_id')::uuid and user_id=owner and phase_id=phase.id and exit_reached
          and defeated_boss_id is not distinct from phase.boss_id and expires_at>now() for update;
      exception when invalid_text_representation then proof:=null;
      end;
      if proof.evidence_id is null or exists(select 1 from qse_v3.phase_completions where evidence_id=proof.evidence_id) then outcome:='rejected'; code:='verification_unavailable';
      else
        insert into qse_v3.phase_completions values(owner,phase.id,proof.evidence_id,now());
        update qse_v3.campaign_progress set active_phase_id=null,checkpoint_id=null where user_id=owner;
        if phase.ordinal=10 and completed=9 then
          insert into qse_v3.player_achievements values(owner,'desert_campaign_completed',now()) on conflict do nothing;
          insert into qse_v3.character_unlocks values(owner,'el_fuego','desert_campaign_completed') on conflict do nothing;
        end if;
      end if;
    end if;
  end if;
  if outcome='applied' then update qse_v3.campaign_progress set revision=revision+1 where user_id=owner; end if;
  response := jsonb_build_object('protocol_version',2,'rules_version','desert_progression_2.0.0',
    'request_id',v_request_id,'status',outcome,'code',code,'snapshot',qse_v3.snapshot(owner));
  if code is distinct from 'idempotency_conflict' then
    insert into qse_v3.processed_requests values(owner,v_request_id,'progression',p_request,response);
  end if;
  return response;
end $$;

-- Nenhuma função ganha execução para PUBLIC/anon por herança do PostgreSQL.
do $permissions$
declare item record;
begin
  for item in select p.oid::regprocedure as signature from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('qse_profile_self','qse_profile_update','qse_account_preferences','qse_profile_public',
      'qse_find_players','qse_friends','qse_friend_action','qse_wallet_history','qse_wallet','qse_progression_snapshot','qse_progression_command') loop
    execute format('revoke all on function %s from public,anon,authenticated',item.signature);
    execute format('grant execute on function %s to authenticated',item.signature);
  end loop;
end $permissions$;
revoke all on all functions in schema qse_v3 from public,anon,authenticated;
grant execute on function qse_v3.post_wallet_entry(uuid,uuid,text,bigint,text) to service_role;
commit;
