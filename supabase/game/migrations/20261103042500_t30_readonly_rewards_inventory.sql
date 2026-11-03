-- T30 — Leitura do inventário de recompensas para a vitrine de Novidades.
-- Motivo: qse_rewards_feed() retorna somente a campanha atual, mas os 11
-- presentes da T29 continuam pertencendo à conta após o lançamento Diva Pop.
-- Não altera concessões, triggers, RLS, campanhas, saldo ou recibos.
begin;
create or replace function public.qse_rewards_inventory()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $function$
declare
  v_user uuid := (select auth.uid());
  v_items jsonb;
begin
  if v_user is null then
    return jsonb_build_object('ok',false,'code','not_authenticated');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,
    'kind',o.item_type,
    'item_id',o.item_id,
    'campaign_id',o.campaign_id,
    'title',o.title,
    'description',o.description,
    'price',o.price,
    'created_at',o.created_at,
    'claimed',true,
    'claimed_at',cl.claimed_at,
    'claim_enabled',false,
    'revealed',(r.user_id is not null)
  ) order by campaign.priority desc,o.sort_order,o.id), '[]'::jsonb)
  into v_items
  from public.qse_reward_claims cl
  join public.qse_reward_offers o on o.id=cl.offer_id
  join public.qse_reward_campaigns campaign on campaign.id=o.campaign_id
  left join public.qse_reward_reveals r on r.user_id=cl.user_id
                                             and r.campaign_id=o.campaign_id
  where cl.user_id=v_user and o.item_type in ('deck','skin') and o.price=0;
  return jsonb_build_object('ok',true,'offers',v_items);
end
$function$;
revoke all on function public.qse_rewards_inventory() from public,anon;
grant execute on function public.qse_rewards_inventory() to authenticated;
commit;
