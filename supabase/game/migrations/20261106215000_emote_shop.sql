-- GAME: preço, débito e posse são decididos pelo servidor, na mesma transação.
begin;
create table qse_v3.emote_products (
  id text primary key check(id ~ '^[a-z0-9_]{1,64}$'),
  name text not null check(char_length(name) between 1 and 80),
  price_coins bigint not null check(price_coins between 1 and 9007199254740991),
  animation_key text not null,
  asset_ready boolean not null default false,
  active boolean not null default false,
  check(not active or asset_ready)
);
create table qse_v3.player_emotes (
  user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  emote_id text not null references qse_v3.emote_products(id),
  transaction_id uuid not null unique references qse_v3.wallet_transactions(transaction_id),
  purchased_at timestamptz not null default now(),
  primary key(user_id,emote_id)
);
alter table qse_v3.emote_products enable row level security;
alter table qse_v3.player_emotes enable row level security;
revoke all on qse_v3.emote_products,qse_v3.player_emotes from public,anon,authenticated;

-- O exemplo não é vendido. Ativar somente depois de publicar o movimento real.
insert into qse_v3.emote_products(id,name,price_coins,animation_key)
 values('dance_01','Dancinha',100,'emote_dance_01');

create function public.qse_emote_shop() returns jsonb
language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid(); v_coins bigint;
begin
 if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
 perform qse_v3.ensure_player(v_user);
 select coins into v_coins from qse_v3.wallets where user_id=v_user;
 return jsonb_build_object('coins',v_coins::text,'items',coalesce((
   select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'price_coins',p.price_coins::text,
    'animation_key',p.animation_key,'available',p.active and p.asset_ready,
    'owned',exists(select 1 from qse_v3.player_emotes e where e.user_id=v_user and e.emote_id=p.id)) order by p.id)
   from qse_v3.emote_products p),'[]'::jsonb));
end;
$function$;

create function public.qse_emote_purchase(p_emote text,p_request uuid,p_expected_price bigint)
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
 if not v_product.active or not v_product.asset_ready then
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
revoke all on function public.qse_emote_shop() from public,anon,authenticated;
revoke all on function public.qse_emote_purchase(text,uuid,bigint) from public,anon,authenticated;
grant execute on function public.qse_emote_shop() to authenticated;
grant execute on function public.qse_emote_purchase(text,uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
