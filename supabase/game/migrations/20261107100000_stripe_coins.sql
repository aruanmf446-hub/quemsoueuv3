-- GAME only. Passive until the owner configures packages AND enables payments.
begin;
create table qse_v3.coin_store_settings (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 live_mode boolean not null default false
);
insert into qse_v3.coin_store_settings default values;
create table qse_v3.coin_packages (
 id text primary key check(id ~ '^[a-z0-9_]{1,64}$'),
 name text not null check(char_length(name) between 1 and 80),
 coins bigint not null check(coins between 1 and 1000000000),
 price_brl_cents integer not null check(price_brl_cents between 50 and 99999999),
 active boolean not null default false
);
create table qse_v3.coin_orders (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 request_id uuid not null,
 package_id text not null references qse_v3.coin_packages(id),
 coins bigint not null,
 amount integer not null,
 currency text not null default 'brl' check(currency='brl'),
 live_mode boolean not null,
 status text not null default 'pending' check(status in ('pending','paid','test_paid','expired','payment_review')),
 session_id text unique,
 checkout_url text,
 payment_intent text unique,
 transaction_id uuid unique references qse_v3.wallet_transactions(transaction_id),
 review_reason text,
 last_event text,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '1 hour'),
 unique(user_id,request_id)
);
create index on qse_v3.coin_orders(user_id,created_at desc);
alter table qse_v3.coin_store_settings enable row level security;
alter table qse_v3.coin_packages enable row level security;
alter table qse_v3.coin_orders enable row level security;
revoke all on qse_v3.coin_store_settings,qse_v3.coin_packages,qse_v3.coin_orders from public,anon,authenticated;

create function public.qse_coin_store() returns jsonb
language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); cfg qse_v3.coin_store_settings%rowtype;
begin
 if u is null then return jsonb_build_object('error','unauthorized'); end if;
 select * into cfg from qse_v3.coin_store_settings;
 return jsonb_build_object('enabled',cfg.enabled,'live_mode',cfg.live_mode,
 'packages',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,
   'coins',p.coins::text,'price_brl_cents',p.price_brl_cents) order by p.price_brl_cents,p.id)
   from qse_v3.coin_packages p where p.active),'[]'::jsonb),
 'orders',coalesce((select jsonb_agg(x.data order by x.created_at desc) from (
   select o.created_at,jsonb_build_object('id',o.id,'request_id',o.request_id,'coins',o.coins::text,'amount',o.amount,
    'status',case when o.status='pending' and o.expires_at<=now() then 'expired' else o.status end,
    'live_mode',o.live_mode,'created_at',o.created_at) data
   from qse_v3.coin_orders o where o.user_id=u order by o.created_at desc limit 10
 ) x),'[]'::jsonb));
end;
$function$;

-- Only the Edge function can prepare orders; p_user comes from /auth/v1/user.
create function public.qse_coin_order_prepare(p_user uuid,p_package text,p_request uuid,
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
  insert into qse_v3.coin_orders(user_id,request_id,package_id,coins,amount,live_mode)
   values(p_user,p_request,pack.id,pack.coins,pack.price_brl_cents,p_live) returning * into o;
 end if;
 return jsonb_build_object('id',o.id,'user_id',o.user_id,'coins',o.coins::text,'amount',o.amount,
  'currency',o.currency,'live_mode',o.live_mode,'expires_at',floor(extract(epoch from o.expires_at))::bigint,
  'session_id',o.session_id,'checkout_url',o.checkout_url);
end;
$function$;

create function public.qse_coin_order_bind(p_order uuid,p_session text,p_url text) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare o qse_v3.coin_orders%rowtype;
begin
 select * into o from qse_v3.coin_orders where id=p_order for update;
 if not found then raise exception 'order_not_found'; end if;
 if o.session_id is not null and o.session_id<>p_session then raise exception 'session_conflict'; end if;
 if p_session is null or p_session !~ '^cs_(test_|live_)?[A-Za-z0-9]+$'
  or p_url is null or p_url !~ '^https://checkout[.]stripe[.]com/' then raise exception 'invalid_checkout'; end if;
 update qse_v3.coin_orders set session_id=p_session,checkout_url=p_url where id=o.id;
 return jsonb_build_object('id',o.id,'url',p_url);
end;
$function$;

-- Caller MUST verify the raw webhook signature and retrieve the canonical Stripe session.
create function public.qse_coin_order_complete(p_order uuid,p_session text,p_intent text,
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
 if p_live then
  entry:=qse_v3.post_wallet_entry(o.user_id,o.id,'coins',o.coins,'coin_topup:'||o.id);
 end if;
 update qse_v3.coin_orders set status=case when p_live then 'paid' else 'test_paid' end,
  payment_intent=p_intent,transaction_id=(entry->>'transaction_id')::uuid,last_event=p_event where id=o.id;
 return jsonb_build_object('status',case when p_live then 'paid' else 'test_paid' end,'duplicate',false);
end;
$function$;

-- Refunds/disputes enter manual review; do not allow already credited coins to be spent.
create function public.qse_coin_order_review(p_order uuid,p_intent text,p_amount integer,
 p_currency text,p_live boolean,p_reason text,p_event text) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare o qse_v3.coin_orders%rowtype;
begin
 select * into o from qse_v3.coin_orders where id=p_order for update;
 if not found then raise exception 'order_not_found'; end if;
 if o.amount is distinct from p_amount or o.currency is distinct from p_currency
  or o.live_mode is distinct from p_live or p_intent is null or p_intent !~ '^pi_[A-Za-z0-9]+$'
  or (o.payment_intent is not null and o.payment_intent<>p_intent)
  or p_reason not in ('refund','dispute') or p_event is null then raise exception 'payment_mismatch'; end if;
 perform 1 from qse_v3.wallets where user_id=o.user_id for update;
 update qse_v3.coin_orders set status='payment_review',payment_intent=p_intent,
  review_reason=p_reason,last_event=p_event where id=o.id;
 return jsonb_build_object('status','payment_review');
end;
$function$;

create function qse_v3.guard_coin_payment_review() returns trigger
language plpgsql security definer set search_path='' as $function$
begin
 if new.coins<old.coins and exists(select 1 from qse_v3.coin_orders
  where user_id=new.user_id and status='payment_review' and live_mode) then
  raise exception 'payment_review'; end if;
 return new;
end;
$function$;
create trigger qse_coin_payment_review before update of coins on qse_v3.wallets
 for each row execute function qse_v3.guard_coin_payment_review();
revoke all on function qse_v3.guard_coin_payment_review() from public,anon,authenticated;
revoke all on function public.qse_coin_store() from public,anon,authenticated;
grant execute on function public.qse_coin_store() to authenticated;
revoke all on function public.qse_coin_order_prepare(uuid,text,uuid,integer,bigint,boolean),
 public.qse_coin_order_bind(uuid,text,text),public.qse_coin_order_complete(uuid,text,text,integer,text,boolean,text),
 public.qse_coin_order_review(uuid,text,integer,text,boolean,text,text) from public,anon,authenticated;
grant execute on function public.qse_coin_order_prepare(uuid,text,uuid,integer,bigint,boolean),
 public.qse_coin_order_bind(uuid,text,text),public.qse_coin_order_complete(uuid,text,text,integer,text,boolean,text),
 public.qse_coin_order_review(uuid,text,integer,text,boolean,text,text) to service_role;
notify pgrst,'reload schema';
commit;
