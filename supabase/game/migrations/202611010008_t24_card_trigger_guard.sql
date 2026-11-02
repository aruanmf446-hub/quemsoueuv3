create or replace function qse_v3.t24_card_guard()
returns trigger language plpgsql security invoker set search_path=''
as $$
declare v_deck uuid; v_status text;
begin
 if tg_op<>'INSERT' then
   if current_user='authenticated' and exists (
     select 1 from public.qse_creator_decks where id=old.deck_id and status<>'draft'
   ) then raise exception 'deck_locked' using errcode='42501'; end if;
 end if;
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
