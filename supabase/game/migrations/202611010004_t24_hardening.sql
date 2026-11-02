-- T24 hardening: UUID estrito e lock de cartas publicadas.
create or replace function public.qse_deck_record_play(p_deck_ref text)
 returns jsonb language plpgsql security definer set search_path = ''
 as $$
 declare v_user uuid := auth.uid(); v_new uuid; v_at timestamptz;
 begin
  if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
  if p_deck_ref is null or (p_deck_ref !~ '^official:[a-z0-9_]{2,64}$' and p_deck_ref !~ '^creator:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    return jsonb_build_object('error','invalid_deck_ref');
  end if;
  if left(p_deck_ref,9)='official:' then
    if not exists(select 1 from qse_v3.duel_decks where id = substring(p_deck_ref from 10)) then
      return jsonb_build_object('error','deck_not_found');
    end if;
  elsif not exists(select 1 from public.qse_creator_decks d where d.id=substring(p_deck_ref from 9)::uuid
    and (d.owner_id=v_user or d.status='published')) then
      return jsonb_build_object('error','deck_not_found');
  end if;
  -- Janela deslizante de 60 minutos, inclusive atravessando mudança de hora UTC.
  -- Serializa tentativas concorrentes do mesmo jogador e deck.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('qse-play:'||v_user::text||':'||p_deck_ref,0));
  if exists(select 1 from public.qse_deck_plays
            where user_id=v_user and deck_ref=p_deck_ref
              and played_at>pg_catalog.now()-interval '1 hour') then
    return jsonb_build_object('deck_ref',p_deck_ref,'recorded',false,
       'played_at',null,'reason','duplicate_hour');
  end if;
  insert into public.qse_deck_plays(deck_ref,user_id)
   values(p_deck_ref,v_user) on conflict (user_id,deck_ref,played_hour) do nothing
   returning id,played_at into v_new,v_at;
  return jsonb_build_object('deck_ref',p_deck_ref,'recorded',v_new is not null,
    'played_at',v_at,'reason',case when v_new is null then 'duplicate_hour' else null end);
 end;
 $$;

create or replace function qse_v3.t24_card_guard()
returns trigger language plpgsql security invoker set search_path=''
as $$
declare v_deck uuid; v_status text;
begin
 if current_user='authenticated' and tg_op<>'INSERT' and exists (
     select 1 from public.qse_creator_decks where id=old.deck_id and status<>'draft'
   ) then raise exception 'deck_locked' using errcode='42501'; end if;
 if tg_op<>'DELETE' then
   select status into v_status from public.qse_creator_decks where id=new.deck_id;
   if current_user='authenticated' and v_status is distinct from 'draft' then
      raise exception 'deck_locked' using errcode='42501';
   end if;
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end;
$$;
