-- T30: Diva Pop como QUINTO deck e nova campanha individual.
-- Já aplicado ao GAME; a UI Godot bloqueia anúncio/recibo antes do upload das dez imagens.
begin;
insert into qse_v3.duel_decks(id,name,card_ids,sort_order)
values('diva_pop','Diva Pop',ARRAY['diva_pop/carta_01','diva_pop/carta_02','diva_pop/carta_03','diva_pop/carta_04','diva_pop/carta_05','diva_pop/carta_06','diva_pop/carta_07','diva_pop/carta_08','diva_pop/carta_09','diva_pop/carta_10']::text[],4)
on conflict(id) do update set name=excluded.name,card_ids=excluded.card_ids,sort_order=excluded.sort_order;

insert into public.qse_reward_campaigns
(id,title,subtitle,description,active,starts_at,ends_at,priority)
values
('diva_pop_2026','DIVA POP CHEGOU!','Novo deck oficial · 10 cartas · grátis',
'Dez novos retratos de estrelas e grupos musicais chegam à comunidade oficial do Quem Sou Eu. A coleção Diva Pop já está disponível gratuitamente na sua conta. Abra o presente para conhecer as cartas e leve o ritmo para o Mata-Mata!',
true,now(),null,110)
on conflict(id) do update set title=excluded.title,subtitle=excluded.subtitle,description=excluded.description,active=true,priority=110;

insert into public.qse_reward_offers
(id,campaign_id,item_type,item_id,title,description,price,active,sort_order,auto_grant)
values
('deck_diva_pop','diva_pop_2026','deck','diva_pop','Diva Pop',
'Um presente de 10 cartas inspirado no brilho e na atitude da música pop mundial. Grátis para toda a comunidade oficial.',0,true,0,true)
on conflict(id) do update set title=excluded.title,description=excluded.description,active=true,auto_grant=true,price=0;

-- Generalizar a concessão automática: considera todas as campanhas oficiais
-- ativas e elegíveis. Novas campanhas continuam isoladas por campanha_id.
create or replace function public.qse_reward_seed_user(p_user_id uuid)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_count integer := 0;
begin
 if p_user_id is null or not exists(select 1 from auth.users u where u.id=p_user_id) then return 0; end if;
 with inserted as (
  insert into public.qse_reward_claims(user_id,offer_id)
  select p_user_id,o.id
  from public.qse_reward_offers o
  join public.qse_reward_campaigns c on c.id=o.campaign_id
  where c.active and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now())
    and o.active and o.price=0 and o.auto_grant
    and (
     (o.item_type='deck' and exists(select 1 from qse_v3.duel_decks d where d.id=o.item_id))
     or
     (o.item_type='skin' and o.item_id in
       ('cowboy','michelly','rodrigo','lorena','gus','lana','halloween')
      and exists(select 1 from qse_v3.character_catalog ch
         where ch.id=o.item_id and ch.initially_unlocked=true))
    )
  on conflict do nothing returning 1
 )
 select count(*) into v_count from inserted;
 return v_count;
end $$;
revoke all on function public.qse_reward_seed_user(uuid) from public,anon,authenticated;
-- A trigger auth.users existente continua chamando a função acima.
-- Backfill de apenas um presente por conta; PK impede duplicar os anteriores.
select count(*) as grants_created from
  (select public.qse_reward_seed_user(id) from auth.users) as grants;
commit;
