-- T29 | Presentes universais: existentes + futuros usuários, entregues uma vez.
-- Mantém o fluxo de história: El Fuego NÃO é presente.
begin;
alter table public.qse_reward_offers
  add column if not exists auto_grant boolean not null default false;

create table if not exists public.qse_reward_reveals (
  user_id uuid not null references auth.users(id) on delete cascade,
  campaign_id text not null references public.qse_reward_campaigns(id) on delete cascade,
  revealed_at timestamptz not null default now(),
  primary key(user_id,campaign_id)
);
alter table public.qse_reward_reveals enable row level security;
revoke all on public.qse_reward_reveals from public, anon, authenticated;

update public.qse_reward_campaigns
set title = 'PRESENTES DA EQUIPE',
    subtitle = '4 decks oficiais + 7 skins iniciais · grátis',
    description = 'Novos decks chegaram à comunidade oficial! A equipe Quem Sou Eu preparou quatro coleções e sete skins iniciais para todas as contas. Os 11 itens ficam guardados gratuitamente na sua conta; abra este presente apenas uma vez.',
    active = true
where id = 'decks_oficiais_2026';

insert into public.qse_reward_offers
(id,campaign_id,item_type,item_id,title,description,price,active,sort_order,auto_grant) values
('skin_cowboy','decks_oficiais_2026','skin','cowboy','Cowboy','O pistoleiro do deserto, pronto para representar você no lobby.',0,true,4,true),
('skin_michelly','decks_oficiais_2026','skin','michelly','Michelly','Personagem inicial disponível para personalizar seu perfil.',0,true,5,true),
('skin_rodrigo','decks_oficiais_2026','skin','rodrigo','Rodrigo','Personagem inicial para entrar nas partidas com seu próprio estilo.',0,true,6,true),
('skin_lorena','decks_oficiais_2026','skin','lorena','Lorena','Uma das aparências iniciais do universo Quem Sou Eu.',0,true,7,true),
('skin_gus','decks_oficiais_2026','skin','gus','Gus','Personagem inicial para escolher e usar em seu avatar.',0,true,8,true),
('skin_lana','decks_oficiais_2026','skin','lana','Lana','Uma das skins iniciais oferecidas a todos os jogadores.',0,true,9,true),
('skin_halloween','decks_oficiais_2026','skin','halloween','Halloween','Personagem inicial de visual misterioso para seu perfil.',0,true,10,true)
on conflict(id) do update set
  title=excluded.title,description=excluded.description,
  sort_order=excluded.sort_order,active=true,auto_grant=true;

update public.qse_reward_offers
set auto_grant=true
where id in ('deck_lendas_urbanas','deck_nostalgia_web','deck_pinturas','deck_sol_nascente')
and campaign_id='decks_oficiais_2026' and item_type='deck' and price=0;

-- Função privada; apenas o trigger de cadastro e rotinas internas a executam.
create or replace function public.qse_reward_seed_user(p_user_id uuid)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_count integer := 0;
begin
  if p_user_id is null or not exists(select 1 from auth.users u where u.id=p_user_id)
  then return 0; end if;
  with inserted as (
    insert into public.qse_reward_claims(user_id,offer_id)
    select p_user_id,o.id
    from public.qse_reward_offers o
    join public.qse_reward_campaigns c on c.id=o.campaign_id
    where c.id='decks_oficiais_2026'
      and c.active and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now())
      and o.active and o.price=0 and o.auto_grant
      and (
        (o.item_type='deck' and exists(select 1 from qse_v3.duel_decks d where d.id=o.item_id))
        or
        (o.item_type='skin' and o.item_id in
          ('cowboy','michelly','rodrigo','lorena','gus','lana','halloween')
         and exists(select 1 from qse_v3.character_catalog ch
           where ch.id=o.item_id and ch.initially_unlocked=true))
      )
    on conflict do nothing
    returning 1
  )
  select count(*) into v_count from inserted;
  return v_count;
end $$;
revoke all on function public.qse_reward_seed_user(uuid) from public,anon,authenticated;

create or replace function public.qse_reward_new_account()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  perform public.qse_reward_seed_user(new.id);
  return new;
end $$;
revoke all on function public.qse_reward_new_account() from public,anon,authenticated;
drop trigger if exists qse_reward_new_account_grants on auth.users;
create trigger qse_reward_new_account_grants
after insert on auth.users for each row
execute function public.qse_reward_new_account();

-- Retroativo para todas as contas existentes, sem substituir resgates anteriores.
select public.qse_reward_seed_user(u.id) from auth.users u;

create or replace function public.qse_rewards_feed()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
 v_uid uuid := (select auth.uid());
 v_campaign public.qse_reward_campaigns%rowtype;
 v_offers jsonb;
begin
 if v_uid is null then return jsonb_build_object('ok',false,'code','not_authenticated'); end if;
 select * into v_campaign from public.qse_reward_campaigns
 where active and starts_at<=now() and (ends_at is null or ends_at>now())
 order by priority desc,starts_at desc limit 1;
 if not found then
  return jsonb_build_object('ok',true,'campaign',null,'seen',true,'revealed',true,'offers','[]'::jsonb);
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',o.id,'kind',o.item_type,'item_id',o.item_id,'title',o.title,
  'description',o.description,'price',o.price,
  'claimed',cl.claimed_at is not null,'claimed_at',cl.claimed_at,
  'claim_enabled',(o.item_type='deck' or (
   o.item_type='skin' and o.item_id in
     ('cowboy','michelly','rodrigo','lorena','gus','lana','halloween')
   and exists(select 1 from qse_v3.character_catalog ch
     where ch.id=o.item_id and ch.initially_unlocked=true)
  ))
 ) order by o.sort_order,o.id),'[]'::jsonb)
 into v_offers from public.qse_reward_offers o
 left join public.qse_reward_claims cl on cl.offer_id=o.id and cl.user_id=v_uid
 where o.campaign_id=v_campaign.id and o.active and o.price=0;
 return jsonb_build_object(
  'ok',true,
  'campaign',jsonb_build_object('id',v_campaign.id,'title',v_campaign.title,
                               'subtitle',v_campaign.subtitle,'description',v_campaign.description),
  'seen',exists(select 1 from public.qse_news_seen s
                where s.user_id=v_uid and s.campaign_id=v_campaign.id),
  'revealed',exists(select 1 from public.qse_reward_reveals r
                    where r.user_id=v_uid and r.campaign_id=v_campaign.id),
  'offers',v_offers);
end $$;

-- "Abrir presentes" é uma confirmação de recebimento. A posse já foi
-- associada à conta no cadastro/backfill; a ação não concede itens duplicados.
create or replace function public.qse_rewards_reveal(p_campaign_id text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_uid uuid := (select auth.uid());
 v_inserted boolean;
begin
 if v_uid is null then return jsonb_build_object('ok',false,'code','not_authenticated'); end if;
 if not exists(select 1 from public.qse_reward_campaigns c
   where c.id=p_campaign_id and c.active and c.starts_at<=now()
   and (c.ends_at is null or c.ends_at>now()))
 then return jsonb_build_object('ok',false,'code','campaign_unavailable'); end if;
 perform public.qse_reward_seed_user(v_uid);
 insert into public.qse_reward_reveals(user_id,campaign_id)
 values(v_uid,p_campaign_id) on conflict do nothing;
 v_inserted := found;
 insert into public.qse_news_seen(user_id,campaign_id)
 values(v_uid,p_campaign_id) on conflict do nothing;
 return jsonb_build_object('ok',true,
   'status',case when v_inserted then 'revealed' else 'already_revealed' end,
   'campaign_id',p_campaign_id);
end $$;
revoke all on function public.qse_rewards_reveal(text) from public,anon;
grant execute on function public.qse_rewards_reveal(text) to authenticated;

-- A API individual é idempotente e pode confirmar skins que já pertencem ao
-- conjunto inicial. Para qualquer skin futura, exige integração real ao GAME.
create or replace function public.qse_rewards_claim(p_offer_id text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_uid uuid := (select auth.uid());
 v_offer public.qse_reward_offers%rowtype;
 v_claimed_at timestamptz;
 v_inserted boolean := false;
begin
 if v_uid is null then return jsonb_build_object('ok',false,'code','not_authenticated'); end if;
 select o.* into v_offer from public.qse_reward_offers o
 join public.qse_reward_campaigns c on c.id=o.campaign_id
 where o.id=p_offer_id and o.active and o.price=0
 and c.active and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now());
 if not found then return jsonb_build_object('ok',false,'code','offer_unavailable'); end if;
 if v_offer.item_type='deck' then
   if not exists(select 1 from qse_v3.duel_decks d where d.id=v_offer.item_id)
   then return jsonb_build_object('ok',false,'code','deck_unavailable'); end if;
 elsif v_offer.item_type='skin' then
   if v_offer.item_id not in ('cowboy','michelly','rodrigo','lorena','gus','lana','halloween')
     or not exists(select 1 from qse_v3.character_catalog c
       where c.id=v_offer.item_id and c.initially_unlocked=true)
   then return jsonb_build_object('ok',false,'code','skin_claim_not_enabled'); end if;
 else return jsonb_build_object('ok',false,'code','offer_unavailable'); end if;
 insert into public.qse_reward_claims(user_id,offer_id)
 values(v_uid,p_offer_id)
 on conflict do nothing returning claimed_at into v_claimed_at;
 v_inserted := found;
 if not v_inserted then
   select claimed_at into v_claimed_at from public.qse_reward_claims
   where user_id=v_uid and offer_id=p_offer_id;
 end if;
 return jsonb_build_object('ok',true,'status',
   case when v_inserted then 'claimed' else 'already_claimed' end,
   'offer_id',v_offer.id,'kind',v_offer.item_type,
   'item_id',v_offer.item_id,'claimed_at',v_claimed_at);
end $$;
revoke all on function public.qse_rewards_claim(text) from public,anon;
grant execute on function public.qse_rewards_claim(text) to authenticated;
commit;
