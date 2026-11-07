-- GAME consumable: one stored refill fills ONE chosen unlocked ability to 3/3.
-- Sales start disabled. Existing gameplay pickups and free/local play are unchanged.
begin;
create table qse_v3.ability_refill_settings (
 singleton boolean primary key default true check(singleton),
 price_coins bigint not null default 10 check(price_coins between 1 and 1000000000),
 active boolean not null default false
);
insert into qse_v3.ability_refill_settings default values;
create table qse_v3.ability_refill_stock (
 user_id uuid primary key references qse_v3.player_profiles(user_id) on delete cascade,
 quantity bigint not null default 0 check(quantity>=0)
);
create table qse_v3.ability_refill_purchases (
 user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 request_id uuid not null,
 price_coins bigint not null,
 transaction_id uuid not null unique references qse_v3.wallet_transactions(transaction_id),
 primary key(user_id,request_id)
);
create table qse_v3.ability_refill_deliveries (
 id uuid primary key,
 user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 ability text not null check(ability in ('attack','defense','amber','dash','rupture')),
 status text not null default 'pending' check(status in ('pending','used')),
 created_at timestamptz not null default now()
);
create index on qse_v3.ability_refill_deliveries(user_id,status);
alter table qse_v3.ability_refill_settings enable row level security;
alter table qse_v3.ability_refill_stock enable row level security;
alter table qse_v3.ability_refill_purchases enable row level security;
alter table qse_v3.ability_refill_deliveries enable row level security;
revoke all on qse_v3.ability_refill_settings,qse_v3.ability_refill_stock,qse_v3.ability_refill_purchases,qse_v3.ability_refill_deliveries from public,anon,authenticated;
create function public.qse_ability_refills() returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); cfg qse_v3.ability_refill_settings%rowtype;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 select * into cfg from qse_v3.ability_refill_settings;
 return jsonb_build_object('price_coins',cfg.price_coins::text,'available',cfg.active and (select cosmetics_enabled from qse_v3.commerce_settings),
 'quantity',coalesce((select quantity from qse_v3.ability_refill_stock where user_id=u),0)::text,
 'pending',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ability',ability) order by created_at) from qse_v3.ability_refill_deliveries where user_id=u and status='pending'),'[]'::jsonb));
end;
$function$;
create function public.qse_ability_refill_buy(p_request uuid,p_expected_price bigint) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); cfg qse_v3.ability_refill_settings%rowtype; prior qse_v3.ability_refill_purchases%rowtype; entry jsonb; balance bigint;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 if p_request is null or p_expected_price is null then return jsonb_build_object('error','invalid_request'); end if;
 select * into cfg from qse_v3.ability_refill_settings for share;
 perform qse_v3.ensure_player(u);
 select coins into balance from qse_v3.wallets where user_id=u for update;
 select * into prior from qse_v3.ability_refill_purchases where user_id=u and request_id=p_request;
 if found then
  if prior.price_coins<>p_expected_price then return jsonb_build_object('error','idempotency_conflict'); end if;
  return jsonb_build_object('purchased',true,'already_purchased',true,'request_id',p_request);
 end if;
 if not cfg.active or not (select cosmetics_enabled from qse_v3.commerce_settings) then return jsonb_build_object('error','sales_disabled'); end if;
 if cfg.price_coins<>p_expected_price then return jsonb_build_object('error','price_changed'); end if;
 if balance<cfg.price_coins then return jsonb_build_object('error','insufficient_funds'); end if;
 -- Avoid a wallet nonce from another product/operation being reused.
 if exists(select 1 from qse_v3.wallet_transactions where user_id=u and idempotency_key=p_request) then return jsonb_build_object('error','idempotency_conflict'); end if;
 entry:=qse_v3.post_wallet_entry(u,p_request,'coins',-cfg.price_coins,'ability_refill');
 insert into qse_v3.ability_refill_purchases values(u,p_request,cfg.price_coins,(entry->>'transaction_id')::uuid);
 insert into qse_v3.ability_refill_stock values(u,1) on conflict(user_id) do update set quantity=qse_v3.ability_refill_stock.quantity+1;
 return jsonb_build_object('purchased',true,'already_purchased',false,'request_id',p_request);
end;
$function$;
-- Reserve before delivery; a lost HTTP response is recovered using the same receipt.
create function public.qse_ability_refill_reserve(p_request uuid,p_ability text) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); r qse_v3.ability_refill_deliveries%rowtype;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 if p_request is null or p_ability is null or p_ability not in ('attack','defense','amber','dash','rupture') then return jsonb_build_object('error','invalid_request'); end if;
 perform qse_v3.ensure_player(u);
 perform 1 from qse_v3.wallets where user_id=u for update;
 if exists(select 1 from qse_v3.coin_orders where user_id=u and status='payment_review' and live_mode) then return jsonb_build_object('error','payment_review'); end if;
 select * into r from qse_v3.ability_refill_deliveries where id=p_request;
 if found then
  if r.user_id<>u or r.ability<>p_ability then return jsonb_build_object('error','idempotency_conflict'); end if;
  return jsonb_build_object('id',r.id,'ability',r.ability,'status',r.status);
 end if;
 update qse_v3.ability_refill_stock set quantity=quantity-1 where user_id=u and quantity>=1;
 if not found then return jsonb_build_object('error','no_refills'); end if;
 insert into qse_v3.ability_refill_deliveries(id,user_id,ability) values(p_request,u,p_ability) returning * into r;
 return jsonb_build_object('id',r.id,'ability',r.ability,'status',r.status);
end;
$function$;
create function public.qse_ability_refill_ack(p_receipt uuid) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); r qse_v3.ability_refill_deliveries%rowtype;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 select * into r from qse_v3.ability_refill_deliveries where id=p_receipt and user_id=u for update;
 if not found then return jsonb_build_object('error','receipt_not_found'); end if;
 update qse_v3.ability_refill_deliveries set status='used' where id=r.id;
 return jsonb_build_object('id',r.id,'used',true);
end;
$function$;
revoke all on function public.qse_ability_refills(),public.qse_ability_refill_buy(uuid,bigint),public.qse_ability_refill_reserve(uuid,text),public.qse_ability_refill_ack(uuid) from public,anon,authenticated;
grant execute on function public.qse_ability_refills(),public.qse_ability_refill_buy(uuid,bigint),public.qse_ability_refill_reserve(uuid,text),public.qse_ability_refill_ack(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
