-- An existing order keeps its original unit type; do not repurpose a package ID.
begin;
alter table qse_v3.cosmetic_products add constraint cosmetic_style_unique unique(kind,character_id,style_id);
create function qse_v3.guard_package_reward_kind() returns trigger
language plpgsql security definer set search_path='' as $function$
begin
 if new.reward_kind<>old.reward_kind and exists(select 1 from qse_v3.coin_orders where package_id=old.id) then
  raise exception 'package_kind_immutable';
 end if;
 return new;
end;
$function$;
create trigger qse_package_reward_kind before update of reward_kind on qse_v3.coin_packages
 for each row execute function qse_v3.guard_package_reward_kind();
revoke all on function qse_v3.guard_package_reward_kind() from public,anon,authenticated;
commit;
