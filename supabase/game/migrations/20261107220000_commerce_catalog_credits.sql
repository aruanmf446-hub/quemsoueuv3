-- GAME: real commerce, initially disabled. Example prices are inactive quotes, not an offer.
begin;
create table qse_v3.commerce_settings (
 singleton boolean primary key default true check(singleton),
 cosmetics_enabled boolean not null default false,
 deck_credits_required boolean not null default false
);
insert into qse_v3.commerce_settings default values;
create table qse_v3.cosmetic_products (
 id text primary key check(id ~ '^[a-z0-9_]{1,80}$'),
 name text not null, kind text not null check(kind in ('skin','variation')),
 character_id text not null references qse_v3.character_catalog(id),
 style_id text, price_coins bigint not null check(price_coins between 1 and 1000000000),
 active boolean not null default false,
 check((kind='skin' and style_id is null) or (kind='variation' and style_id in ('style_1','style_2')))
);
create table qse_v3.player_cosmetics (
 user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 product_id text not null references qse_v3.cosmetic_products(id),
 transaction_id uuid not null unique references qse_v3.wallet_transactions(transaction_id),
 primary key(user_id,product_id)
);
create table qse_v3.player_variations (
 user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 character_id text not null references qse_v3.character_catalog(id),
 product_id text not null references qse_v3.cosmetic_products(id),
 primary key(user_id,character_id)
);
create table qse_v3.deck_credit_balances (
 user_id uuid primary key references qse_v3.player_profiles(user_id) on delete cascade,
 credits bigint not null default 0 check(credits>=0)
);
create table qse_v3.deck_credit_receipts (
 order_id uuid primary key references qse_v3.coin_orders(id) on delete cascade,
 user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 amount bigint not null check(amount>0)
);
create table qse_v3.deck_credit_spends (
 deck_id uuid primary key,
 user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 spent_at timestamptz not null default now()
);
alter table qse_v3.coin_packages add column reward_kind text not null default 'coins' check(reward_kind in ('coins','deck_credits'));
alter table qse_v3.coin_orders add column reward_kind text not null default 'coins' check(reward_kind in ('coins','deck_credits'));
alter table qse_v3.commerce_settings enable row level security;
revoke all on qse_v3.commerce_settings from public,anon,authenticated;
alter table qse_v3.cosmetic_products enable row level security;
revoke all on qse_v3.cosmetic_products from public,anon,authenticated;
alter table qse_v3.player_cosmetics enable row level security;
revoke all on qse_v3.player_cosmetics from public,anon,authenticated;
alter table qse_v3.player_variations enable row level security;
revoke all on qse_v3.player_variations from public,anon,authenticated;
alter table qse_v3.deck_credit_balances enable row level security;
revoke all on qse_v3.deck_credit_balances from public,anon,authenticated;
alter table qse_v3.deck_credit_receipts enable row level security;
revoke all on qse_v3.deck_credit_receipts from public,anon,authenticated;
alter table qse_v3.deck_credit_spends enable row level security;
revoke all on qse_v3.deck_credit_spends from public,anon,authenticated;
create or replace function public.qse_coin_store() returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); cfg qse_v3.coin_store_settings%rowtype;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 select * into cfg from qse_v3.coin_store_settings;
 return jsonb_build_object('enabled',cfg.enabled,'live_mode',cfg.live_mode,
 'packages',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,
   'coins',p.coins::text,'reward_kind',p.reward_kind,'available',p.active and cfg.enabled,'price_brl_cents',p.price_brl_cents) order by p.price_brl_cents,p.id)
   from qse_v3.coin_packages p ),'[]'::jsonb),
 'orders',coalesce((select jsonb_agg(x.data order by x.created_at desc) from (
   select o.created_at,jsonb_build_object('id',o.id,'request_id',o.request_id,'coins',o.coins::text,'amount',o.amount,'reward_kind',o.reward_kind,
    'status',case when o.status='pending' and o.expires_at<=now() then 'expired' else o.status end,
    'live_mode',o.live_mode,'created_at',o.created_at) data
   from qse_v3.coin_orders o where o.user_id=u order by o.created_at desc limit 10
 ) x),'[]'::jsonb));
end;
$function$;
create or replace function public.qse_coin_order_prepare(p_user uuid,p_package text,p_request uuid,
 p_expected_amount integer,p_expected_coins bigint,p_live boolean) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare cfg qse_v3.coin_store_settings%rowtype; pack qse_v3.coin_packages%rowtype;
 o qse_v3.coin_orders%rowtype;
begin
 select * into cfg from qse_v3.coin_store_settings for share;
 if not cfg.enabled or p_live is distinct from cfg.live_mode then
  return jsonb_build_object('error','payments_unavailable'); end if;
 if p_user is null or p_request is null then return jsonb_build_object('error','invalid_request'); end if;
 perform qse_v3.ensure_player(p_user);
 perform 1 from qse_v3.wallets where user_id=p_user for update;
 if exists(select 1 from qse_v3.coin_orders where user_id=p_user and status='payment_review') then
  return jsonb_build_object('error','payment_review'); end if;
 select * into o from qse_v3.coin_orders where user_id=p_user and request_id=p_request;
 if found then
  if o.package_id is distinct from p_package or o.amount is distinct from p_expected_amount
    or o.coins is distinct from p_expected_coins or o.live_mode is distinct from p_live then
    return jsonb_build_object('error','idempotency_conflict'); end if;
  if o.status<>'pending' or o.expires_at<=now()+interval '30 minutes' then
    return jsonb_build_object('error','order_expired'); end if;
 else
  select * into pack from qse_v3.coin_packages where id=p_package and active for share;
  if not found then return jsonb_build_object('error','package_unavailable'); end if;
  if pack.price_brl_cents is distinct from p_expected_amount or pack.coins is distinct from p_expected_coins then
   return jsonb_build_object('error','price_changed'); end if;
  if (select count(*) from qse_v3.coin_orders where user_id=p_user and created_at>now()-interval '1 hour')>=5 then
   return jsonb_build_object('error','rate_limit'); end if;
  insert into qse_v3.coin_orders(user_id,request_id,package_id,coins,amount,live_mode,reward_kind)
   values(p_user,p_request,pack.id,pack.coins,pack.price_brl_cents,p_live,pack.reward_kind) returning * into o;
 end if;
 return jsonb_build_object('id',o.id,'user_id',o.user_id,'coins',o.coins::text,'amount',o.amount,
  'reward_kind',o.reward_kind,'currency',o.currency,'live_mode',o.live_mode,'expires_at',floor(extract(epoch from o.expires_at))::bigint,
  'session_id',o.session_id,'checkout_url',o.checkout_url);
end;
$function$;
create or replace function public.qse_coin_order_complete(p_order uuid,p_session text,p_intent text,
 p_amount integer,p_currency text,p_live boolean,p_event text) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare o qse_v3.coin_orders%rowtype; entry jsonb;
begin
 select * into o from qse_v3.coin_orders where id=p_order for update;
 if not found then raise exception 'order_not_found'; end if;
 if o.session_id is distinct from p_session or o.amount is distinct from p_amount
  or o.currency is distinct from p_currency or o.live_mode is distinct from p_live
  or p_intent is null or p_intent !~ '^pi_[A-Za-z0-9]+$' or p_event is null then
  raise exception 'payment_mismatch'; end if;
 if o.payment_intent is not null and o.payment_intent<>p_intent then raise exception 'payment_mismatch'; end if;
 if o.status='payment_review' then return jsonb_build_object('status',o.status); end if;
 if o.status in ('paid','test_paid') then return jsonb_build_object('status',o.status,'duplicate',true); end if;
 if p_live and o.reward_kind='coins' then
  entry:=qse_v3.post_wallet_entry(o.user_id,o.id,'coins',o.coins,'coin_topup:'||o.id);
 end if;
 if p_live and o.reward_kind='deck_credits' then
  insert into qse_v3.deck_credit_balances(user_id) values(o.user_id) on conflict do nothing;
  insert into qse_v3.deck_credit_receipts values(o.id,o.user_id,o.coins);
  update qse_v3.deck_credit_balances set credits=credits+o.coins where user_id=o.user_id;
 end if;
 update qse_v3.coin_orders set status=case when p_live then 'paid' else 'test_paid' end,
  payment_intent=p_intent,transaction_id=(entry->>'transaction_id')::uuid,last_event=p_event where id=o.id;
 return jsonb_build_object('status',case when p_live then 'paid' else 'test_paid' end,'duplicate',false);
end;
$function$;
create function public.qse_cosmetic_shop() returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); cfg qse_v3.commerce_settings%rowtype;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 perform qse_v3.ensure_player(u);
 select * into cfg from qse_v3.commerce_settings;
 return jsonb_build_object('enabled',cfg.cosmetics_enabled,'deck_credits_required',cfg.deck_credits_required,
 'deck_credits',coalesce((select credits from qse_v3.deck_credit_balances where user_id=u),0)::text,
 'items',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'kind',p.kind,
 'character_id',p.character_id,'style_id',p.style_id,'price_coins',p.price_coins::text,
 'available',cfg.cosmetics_enabled and p.active,'owned',exists(select 1 from qse_v3.player_cosmetics e where e.user_id=u and e.product_id=p.id)))
 from qse_v3.cosmetic_products p),'[]'::jsonb),
 'equipped',coalesce((select jsonb_object_agg(e.character_id,p.style_id) from qse_v3.player_variations e join qse_v3.cosmetic_products p on p.id=e.product_id where e.user_id=u),'{}'::jsonb));
end;
$function$;
create function public.qse_cosmetic_purchase(p_product text,p_request uuid,p_expected_price bigint) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); p qse_v3.cosmetic_products%rowtype; balance bigint; entry jsonb; prior qse_v3.wallet_transactions%rowtype; receipt uuid;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 if p_request is null or p_expected_price is null or p_expected_price<1 then return jsonb_build_object('error','invalid_request'); end if;
 select * into p from qse_v3.cosmetic_products where id=p_product for share;
 if not found then return jsonb_build_object('error','product_unavailable'); end if;
 perform qse_v3.ensure_player(u);
 select coins into balance from qse_v3.wallets where user_id=u for update;
 select * into prior from qse_v3.wallet_transactions where user_id=u and idempotency_key=p_request;
 if found and (prior.reason<>'cosmetic:'||p_product or prior.amount<>-p_expected_price or prior.currency<>'coins') then return jsonb_build_object('error','idempotency_conflict'); end if;
 select transaction_id into receipt from qse_v3.player_cosmetics where user_id=u and product_id=p_product;
 if found then return jsonb_build_object('owned',true,'already_owned',true,'product_id',p_product,'coins_after',balance::text); end if;
 if not (select cosmetics_enabled from qse_v3.commerce_settings) or not p.active then return jsonb_build_object('error','sales_disabled'); end if;
 if p.price_coins<>p_expected_price then return jsonb_build_object('error','price_changed'); end if;
 -- Never sell existing free skins, campaign rewards, or a variation of an unowned skin.
 if p.kind='skin' and exists(select 1 from qse_v3.character_catalog where id=p.character_id and (initially_unlocked or required_achievement is not null)) then return jsonb_build_object('error','protected_character'); end if;
 if exists(select 1 from qse_v3.character_unlocks where user_id=u and character_id=p.character_id) and p.kind='skin' then return jsonb_build_object('error','already_unlocked'); end if;
 if p.kind='variation' and not exists(select 1 from qse_v3.character_unlocks where user_id=u and character_id=p.character_id) then return jsonb_build_object('error','locked_character'); end if;
 if balance<p.price_coins then return jsonb_build_object('error','insufficient_funds'); end if;
 entry:=qse_v3.post_wallet_entry(u,p_request,'coins',-p.price_coins,'cosmetic:'||p_product);
 insert into qse_v3.player_cosmetics values(u,p_product,(entry->>'transaction_id')::uuid);
 if p.kind='skin' then
  insert into qse_v3.character_unlocks(user_id,character_id) values(u,p.character_id);
  update qse_v3.campaign_progress set revision=revision+1 where user_id=u;
 end if;
 return jsonb_build_object('owned',true,'already_owned',false,'product_id',p_product,'coins_after',entry->>'balance_after');
end;
$function$;
create function public.qse_variation_equip(p_character text,p_style text) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); id text;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 perform qse_v3.ensure_player(u);
 perform 1 from qse_v3.wallets where user_id=u for update;
 if not exists(select 1 from qse_v3.character_unlocks where user_id=u and character_id=p_character) then return jsonb_build_object('error','locked_character'); end if;
 if p_style='original' then delete from qse_v3.player_variations where user_id=u and character_id=p_character;
 else
  select p.id into id from qse_v3.cosmetic_products p join qse_v3.player_cosmetics e on e.product_id=p.id and e.user_id=u where p.kind='variation' and p.character_id=p_character and p.style_id=p_style order by p.id limit 1;
  if id is null then return jsonb_build_object('error','not_owned'); end if;
  insert into qse_v3.player_variations values(u,p_character,id) on conflict(user_id,character_id) do update set product_id=excluded.product_id;
 end if;
 return jsonb_build_object('character_id',p_character,'style_id',p_style);
end;
$function$;
create function qse_v3.consume_deck_credit() returns trigger
language plpgsql security definer set search_path='' as $function$
begin
 if not (select deck_credits_required from qse_v3.commerce_settings) then return new; end if;
 -- Also protects direct REST inserts. Updates/rejection/resubmission never charge again.
 perform qse_v3.ensure_player(new.owner_id);
 perform 1 from qse_v3.wallets where user_id=new.owner_id for update;
 if exists(select 1 from qse_v3.coin_orders where user_id=new.owner_id and status='payment_review' and live_mode) then raise exception 'payment_review'; end if;
 if exists(select 1 from qse_v3.deck_credit_spends where deck_id=new.id) then raise exception 'deck_id_already_used'; end if;
 update qse_v3.deck_credit_balances set credits=credits-1 where user_id=new.owner_id and credits>=1;
 if not found then raise exception 'insufficient_deck_credits'; end if;
 insert into qse_v3.deck_credit_spends(deck_id,user_id) values(new.id,new.owner_id);
 return new;
end;
$function$;
create trigger qse_deck_credit_consume after insert on public.qse_creator_decks for each row execute function qse_v3.consume_deck_credit();
revoke all on function qse_v3.consume_deck_credit() from public,anon,authenticated;
revoke all on function public.qse_cosmetic_shop() from public,anon,authenticated;
grant execute on function public.qse_cosmetic_shop() to authenticated;
revoke all on function public.qse_cosmetic_purchase(text,uuid,bigint) from public,anon,authenticated;
grant execute on function public.qse_cosmetic_purchase(text,uuid,bigint) to authenticated;
revoke all on function public.qse_variation_equip(text,text) from public,anon,authenticated;
grant execute on function public.qse_variation_equip(text,text) to authenticated;

-- Owner examples are stored inactive; their final commercial prices remain to be confirmed.
insert into qse_v3.coin_packages(id,name,coins,price_brl_cents,reward_kind) values
 ('coins_100','100 moedas',100,1000,'coins'),('coins_250','250 moedas',250,2000,'coins'),
 ('coins_400','400 moedas',400,3000,'coins'),('deck_credit','1 crédito de deck',1,1000,'deck_credits');
insert into qse_v3.emote_products(id,name,price_coins,animation_key,asset_ready,active) values('samba','Samba',50,'emote_samba',true,false);
insert into qse_v3.cosmetic_products(id,name,kind,character_id,style_id,price_coins)
 select c.id||'_'||s.id,c.id||' · '||s.name,'variation',c.id,s.id,100
 from qse_v3.character_catalog c cross join (values('style_1','Variação 1'),('style_2','Variação 2')) s(id,name);
create or replace function public.qse_emote_purchase(p_emote text,p_request uuid,p_expected_price bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid(); v_product qse_v3.emote_products%rowtype;
 v_coins bigint; v_owned qse_v3.player_emotes%rowtype;
 v_prior qse_v3.wallet_transactions%rowtype; v_entry jsonb; v_reason text;
begin
 if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
 if p_request is null or p_expected_price is null or p_expected_price<1 then
   return jsonb_build_object('error','invalid_request'); end if;
 select * into v_product from qse_v3.emote_products where id=p_emote for share;
 if not found then return jsonb_build_object('error','emote_not_found'); end if;
 perform qse_v3.ensure_player(v_user);
 -- Uma carteira por vez: inclusive requisições simultâneas com UUIDs diferentes.
 select coins into v_coins from qse_v3.wallets where user_id=v_user for update;
 v_reason:='emote:'||p_emote;
 select * into v_prior from qse_v3.wallet_transactions
   where user_id=v_user and idempotency_key=p_request;
 if found and (v_prior.reason<>v_reason or v_prior.currency<>'coins'
   or v_prior.amount<>-p_expected_price) then
   return jsonb_build_object('error','idempotency_conflict'); end if;
 select * into v_owned from qse_v3.player_emotes where user_id=v_user and emote_id=p_emote;
 if found then return jsonb_build_object('owned',true,'already_owned',true,
   'emote_id',p_emote,'coins_after',v_coins::text,'transaction_id',v_owned.transaction_id); end if;
 if not (select cosmetics_enabled from qse_v3.commerce_settings) or not v_product.active or not v_product.asset_ready then
   return jsonb_build_object('error','emote_unavailable'); end if;
 if v_product.price_coins<>p_expected_price then
   return jsonb_build_object('error','price_changed'); end if;
 if v_coins<v_product.price_coins then return jsonb_build_object('error','insufficient_funds'); end if;
 v_entry:=qse_v3.post_wallet_entry(v_user,p_request,'coins',-v_product.price_coins,v_reason);
 insert into qse_v3.player_emotes(user_id,emote_id,transaction_id)
   values(v_user,p_emote,(v_entry->>'transaction_id')::uuid);
 return jsonb_build_object('owned',true,'already_owned',false,'emote_id',p_emote,
   'coins_after',v_entry->>'balance_after','transaction_id',v_entry->>'transaction_id');
end;
$function$;
notify pgrst,'reload schema';
commit;
