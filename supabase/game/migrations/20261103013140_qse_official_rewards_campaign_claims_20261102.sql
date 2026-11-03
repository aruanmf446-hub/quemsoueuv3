-- QSE V3 | official free rewards + per-account news receipts
-- No automatic grants. Skins require a separate progression contract integration.
create table if not exists public.qse_reward_campaigns (
 id text primary key check(id ~ '^[a-z0-9_]{3,64}$'),
 title text not null check(char_length(title) between 3 and 120),
 subtitle text not null default '',
 description text not null default '',
 active boolean not null default false,
 starts_at timestamptz not null default now(),
 ends_at timestamptz,
 priority integer not null default 0,
 created_at timestamptz not null default now(),
 constraint reward_campaign_dates check (ends_at is null or ends_at > starts_at)
);
create table if not exists public.qse_reward_offers (
 id text primary key check(id ~ '^[a-z0-9_]{3,64}$'),
 campaign_id text not null references public.qse_reward_campaigns(id) on delete restrict,
 item_type text not null check(item_type in ('deck','skin')),
 item_id text not null check(item_id ~ '^[a-z0-9_]{2,64}$'),
 title text not null check(char_length(title) between 2 and 120),
 description text not null default '',
 price integer not null default 0 check(price=0),
 active boolean not null default true,
 sort_order integer not null default 0,
 created_at timestamptz not null default now(),
 unique(campaign_id,item_type,item_id)
);
create table if not exists public.qse_reward_claims (
 user_id uuid not null references auth.users(id) on delete cascade,
 offer_id text not null references public.qse_reward_offers(id) on delete restrict,
 claimed_at timestamptz not null default now(),
 primary key(user_id,offer_id)
);
create index if not exists qse_reward_claims_offer_idx on public.qse_reward_claims(offer_id);
create table if not exists public.qse_news_seen (
 user_id uuid not null references auth.users(id) on delete cascade,
 campaign_id text not null references public.qse_reward_campaigns(id) on delete cascade,
 seen_at timestamptz not null default now(),
 primary key(user_id,campaign_id)
);
alter table public.qse_reward_campaigns enable row level security;
alter table public.qse_reward_offers enable row level security;
alter table public.qse_reward_claims enable row level security;
alter table public.qse_news_seen enable row level security;
-- Data access only through audited, account-scoped RPCs. No direct client writes.
revoke all on public.qse_reward_campaigns,public.qse_reward_offers,public.qse_reward_claims,public.qse_news_seen from public,anon,authenticated;
create or replace function public.qse_rewards_feed()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
 v_uid uuid := (select auth.uid());
 v_campaign public.qse_reward_campaigns%rowtype;
 v_offers jsonb;
begin
 if v_uid is null then return jsonb_build_object('ok',false,'code','not_authenticated'); end if;
 select * into v_campaign from public.qse_reward_campaigns
 where active and starts_at <= now() and (ends_at is null or ends_at > now())
 order by priority desc,starts_at desc limit 1;
 if not found then return jsonb_build_object('ok',true,'campaign',null,'seen',true,'offers','[]'::jsonb); end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',o.id,'kind',o.item_type,'item_id',o.item_id,'title',o.title,
 'description',o.description,'price',o.price,
 'claimed',cl.claimed_at is not null,'claimed_at',cl.claimed_at
 ) order by o.sort_order,o.id),'[]'::jsonb)
 into v_offers from public.qse_reward_offers o
 left join public.qse_reward_claims cl on cl.offer_id=o.id and cl.user_id=v_uid
 where o.campaign_id=v_campaign.id and o.active and o.price=0;
 return jsonb_build_object(
 'ok',true,
 'campaign',jsonb_build_object('id',v_campaign.id,'title',v_campaign.title,'subtitle',v_campaign.subtitle,'description',v_campaign.description),
 'seen',exists(select 1 from public.qse_news_seen s where s.user_id=v_uid and s.campaign_id=v_campaign.id),
 'offers',v_offers);
end $$;
create or replace function public.qse_rewards_mark_seen(p_campaign_id text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid());
begin
 if v_uid is null then return jsonb_build_object('ok',false,'code','not_authenticated'); end if;
 if not exists(select 1 from public.qse_reward_campaigns
 where id=p_campaign_id and active and starts_at <= now() and (ends_at is null or ends_at > now()))
 then return jsonb_build_object('ok',false,'code','campaign_unavailable'); end if;
 insert into public.qse_news_seen(user_id,campaign_id) values(v_uid,p_campaign_id) on conflict do nothing;
 return jsonb_build_object('ok',true,'campaign_id',p_campaign_id,'seen',true);
end $$;
create or replace function public.qse_rewards_claim(p_offer_id text)
returns jsonb language plpgsql security definer set search_path = ''
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
 else
   -- Current progression snapshots use a strict, fixed skin set. Do not fake ownership.
   return jsonb_build_object('ok',false,'code','skin_claim_not_enabled');
 end if;
 insert into public.qse_reward_claims(user_id,offer_id)
 values(v_uid,p_offer_id)
 on conflict do nothing returning claimed_at into v_claimed_at;
 v_inserted := found;
 if not v_inserted then
   select claimed_at into v_claimed_at from public.qse_reward_claims
   where user_id=v_uid and offer_id=p_offer_id;
 end if;
 return jsonb_build_object('ok',true,'status',case when v_inserted then 'claimed' else 'already_claimed' end,
 'offer_id',v_offer.id,'kind',v_offer.item_type,'item_id',v_offer.item_id,'claimed_at',v_claimed_at);
end $$;
revoke all on function public.qse_rewards_feed() from public,anon;
revoke all on function public.qse_rewards_mark_seen(text) from public,anon;
revoke all on function public.qse_rewards_claim(text) from public,anon;
grant execute on function public.qse_rewards_feed() to authenticated;
grant execute on function public.qse_rewards_mark_seen(text) to authenticated;
grant execute on function public.qse_rewards_claim(text) to authenticated;
insert into public.qse_reward_campaigns(id,title,subtitle,description,active,priority)
values('decks_oficiais_2026','NOVOS DECKS OFICIAIS','4 coleções especiais · 37 cartas',
'Novos decks adicionados à comunidade oficial, criados pela equipe Quem Sou Eu. Receba gratuitamente na sua conta e leve suas coleções para as próximas partidas.',true,100)
on conflict(id) do update set title=excluded.title,subtitle=excluded.subtitle,description=excluded.description,active=true,priority=excluded.priority;
insert into public.qse_reward_offers(id,campaign_id,item_type,item_id,title,description,price,active,sort_order) values
('deck_nostalgia_web','decks_oficiais_2026','deck','nostalgia_web','Nostalgia Web','10 cartas com memes, expressões e referências marcantes da cultura digital.',0,true,0),
('deck_sol_nascente','decks_oficiais_2026','deck','sol_nascente','Sol Nascente','10 cartas inspiradas em lendas, guerreiros e tradições japonesas.',0,true,1),
('deck_pinturas','decks_oficiais_2026','deck','pinturas','Pinturas','8 releituras de obras icônicas da história da arte.',0,true,2),
('deck_lendas_urbanas','decks_oficiais_2026','deck','lendas_urbanas','Lendas Urbanas','9 cartas de assombrações, criaturas folclóricas e terror da internet.',0,true,3)
on conflict(id) do update set title=excluded.title,description=excluded.description,active=true,sort_order=excluded.sort_order;
