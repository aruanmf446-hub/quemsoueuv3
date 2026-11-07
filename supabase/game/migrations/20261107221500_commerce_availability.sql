-- Keep public availability consistent with the server kill switch.
begin;
create or replace function public.qse_emote_shop() returns jsonb
language plpgsql security definer set search_path='' as $function$
declare v_user uuid:=auth.uid(); v_coins bigint;
begin
 if v_user is null then return jsonb_build_object('error','unauthorized'); end if;
 perform qse_v3.ensure_player(v_user);
 select coins into v_coins from qse_v3.wallets where user_id=v_user;
 return jsonb_build_object('coins',v_coins::text,'items',coalesce((
   select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'price_coins',p.price_coins::text,
    'animation_key',p.animation_key,'available',p.active and p.asset_ready and (select cosmetics_enabled from qse_v3.commerce_settings),
    'owned',exists(select 1 from qse_v3.player_emotes e where e.user_id=v_user and e.emote_id=p.id)) order by p.id)
   from qse_v3.emote_products p),'[]'::jsonb));
end;
$function$;
notify pgrst,'reload schema';
commit;
