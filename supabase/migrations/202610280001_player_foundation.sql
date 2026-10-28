-- Aplicar somente após preflight.sql e revisão do projeto remoto. Nenhuma tabela existente é substituída.
begin;
-- Harden the existing DDL helper without removing its event trigger.
do $helper_acl$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public,anon,authenticated;
  end if;
end $helper_acl$;
create schema qse_v3;
revoke all on schema qse_v3 from public,anon,authenticated;
-- API exposure remains public RPCs only; no direct client writes.
alter default privileges in schema qse_v3 revoke all on tables from public,anon,authenticated;
alter default privileges in schema qse_v3 revoke all on sequences from public,anon,authenticated;
alter default privileges in schema qse_v3 revoke execute on functions from public,anon,authenticated;
grant usage on schema qse_v3 to authenticated, service_role;

create table qse_v3.character_catalog (
  id text primary key,
  initially_unlocked boolean not null,
  required_achievement text,
  check (id in ('cowboy','michelly','rodrigo','lorena','gus','lana','halloween','el_fuego')),
  check ((id = 'el_fuego' and not initially_unlocked and required_achievement is not distinct from 'desert_campaign_completed')
    or (id <> 'el_fuego' and initially_unlocked and required_achievement is null))
);
insert into qse_v3.character_catalog values
 ('cowboy',true,null),('michelly',true,null),('rodrigo',true,null),('lorena',true,null),
 ('gus',true,null),('lana',true,null),('halloween',true,null),('el_fuego',false,'desert_campaign_completed');

create table qse_v3.desert_phases (
  id text primary key,
  ordinal integer not null unique check (ordinal between 1 and 10),
  boss_id text,
  checkpoint_ids text[] not null,
  check (id = 'desert_phase_' || lpad(ordinal::text,2,'0')),
  check ((ordinal < 10 and boss_id is null) or (ordinal = 10 and boss_id is not distinct from 'malagueta'))
);
insert into qse_v3.desert_phases
select 'desert_phase_' || lpad(n::text,2,'0'), n,
  case when n = 10 then 'malagueta' end,
  case when n = 10 then array['desert_phase_10_checkpoint_01'] else
    array['desert_phase_' || lpad(n::text,2,'0') || '_checkpoint_01',
          'desert_phase_' || lpad(n::text,2,'0') || '_checkpoint_02'] end
from generate_series(1,10) n;

create table qse_v3.player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  public_id text not null unique default ('QSE-' || replace(pg_catalog.gen_random_uuid()::text,'-','')),
  nickname text check (nickname is null or (char_length(nickname) between 3 and 24 and nickname !~ '[[:cntrl:]]')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table qse_v3.account_preferences (
  user_id uuid primary key references qse_v3.player_profiles(user_id) on delete cascade,
  discoverable boolean not null default true,
  updated_at timestamptz not null default now()
);
create table qse_v3.player_statistics (
  user_id uuid primary key references qse_v3.player_profiles(user_id) on delete cascade,
  level integer check (level >= 0),
  experience bigint check (experience >= 0),
  statistics jsonb not null default '{}' check (jsonb_typeof(statistics) = 'object')
);
create table qse_v3.campaign_progress (
  user_id uuid primary key references qse_v3.player_profiles(user_id) on delete cascade,
  campaign_id text not null default 'desert_campaign' check (campaign_id = 'desert_campaign'),
  revision bigint not null default 0 check (revision between 0 and 9007199254740991),
  active_phase_id text references qse_v3.desert_phases(id),
  checkpoint_id text,
  check (checkpoint_id is null or active_phase_id is not null)
);
-- Somente o futuro verificador de gameplay, em ambiente servidor, poderá produzir provas.
-- O cliente não pode inserir, ler ou declarar uma prova como verificada.
create table qse_v3.completion_evidence (
  evidence_id uuid primary key,
  user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  attempt_id uuid not null unique,
  phase_id text not null references qse_v3.desert_phases(id),
  exit_reached boolean not null check (exit_reached),
  defeated_boss_id text,
  expires_at timestamptz not null,
  unique (user_id,phase_id,evidence_id),
  check ((phase_id = 'desert_phase_10' and defeated_boss_id is not distinct from 'malagueta')
    or (phase_id <> 'desert_phase_10' and defeated_boss_id is null))
);
create table qse_v3.phase_completions (
  user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  phase_id text not null references qse_v3.desert_phases(id),
  evidence_id uuid not null unique,
  completed_at timestamptz not null default now(),
  primary key (user_id,phase_id),
  foreign key (user_id,phase_id,evidence_id) references qse_v3.completion_evidence(user_id,phase_id,evidence_id)
);
create table qse_v3.player_achievements (
  user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  achievement_id text not null check (achievement_id = 'desert_campaign_completed'),
  awarded_at timestamptz not null default now(),
  primary key (user_id,achievement_id)
);
create table qse_v3.character_unlocks (
  user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  character_id text not null references qse_v3.character_catalog(id),
  achievement_id text,
  primary key (user_id,character_id),
  foreign key (user_id,achievement_id) references qse_v3.player_achievements(user_id,achievement_id),
  check ((character_id = 'el_fuego' and achievement_id is not distinct from 'desert_campaign_completed')
    or (character_id <> 'el_fuego' and achievement_id is null))
);
create table qse_v3.player_loadout (
  user_id uuid primary key references qse_v3.player_profiles(user_id) on delete cascade,
  equipped_character_id text not null,
  updated_at timestamptz not null default now(),
  foreign key (user_id,equipped_character_id) references qse_v3.character_unlocks(user_id,character_id)
);
create table qse_v3.friendships (
  user_low uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  user_high uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low,user_high),
  check (user_low < user_high)
);
create table qse_v3.friend_requests (
  sender_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  recipient_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (sender_id,recipient_id),
  check (sender_id <> recipient_id)
);
create index friend_requests_recipient on qse_v3.friend_requests(recipient_id);
create table qse_v3.processed_requests (
  user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  request_id uuid not null,
  domain text not null check (domain in ('progression','friends')),
  request jsonb not null,
  response jsonb not null,
  primary key (user_id,domain,request_id)
);
create table qse_v3.wallets (
  user_id uuid primary key references qse_v3.player_profiles(user_id) on delete cascade,
  coins bigint not null default 0 check (coins >= 0),
  gems bigint not null default 0 check (gems >= 0),
  revision bigint not null default 0 check (revision >= 0)
);
create table qse_v3.wallet_transactions (
  sequence bigint generated always as identity unique,
  transaction_id uuid primary key default pg_catalog.gen_random_uuid(),
  user_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
  idempotency_key uuid not null,
  currency text not null check (currency in ('coins','gems')),
  amount bigint not null check (amount <> 0),
  balance_after bigint not null check (balance_after >= 0),
  reason text not null check (char_length(reason) between 1 and 120),
  created_at timestamptz not null default now(),
  unique (user_id,idempotency_key)
);
create index wallet_history_owner on qse_v3.wallet_transactions(user_id,sequence desc);

revoke all on all tables in schema qse_v3 from public,anon,authenticated;
revoke all on all sequences in schema qse_v3 from public,anon,authenticated;

-- RLS: leitura privada ao dono; escrita de economia/progresso/carga/amizades só por funções.
do $rls$
declare item text;
begin
  foreach item in array array['player_profiles','account_preferences','player_statistics','campaign_progress',
    'phase_completions','player_achievements','character_unlocks','player_loadout','wallets','wallet_transactions'] loop
    execute format('alter table qse_v3.%I enable row level security',item);
    execute format('create policy owner_read on qse_v3.%I for select to authenticated using (user_id = (select auth.uid()))',item);
    execute format('grant select on qse_v3.%I to authenticated',item);
  end loop;
end $rls$;
alter table qse_v3.character_catalog enable row level security;
alter table qse_v3.desert_phases enable row level security;
alter table qse_v3.completion_evidence enable row level security;
alter table qse_v3.processed_requests enable row level security;
alter table qse_v3.friendships enable row level security;
alter table qse_v3.friend_requests enable row level security;
create policy participants_read on qse_v3.friendships for select to authenticated
  using ((select auth.uid()) in (user_low,user_high));
create policy participants_read on qse_v3.friend_requests for select to authenticated
  using ((select auth.uid()) in (sender_id,recipient_id));
grant select on qse_v3.friendships,qse_v3.friend_requests to authenticated;
grant all on all tables in schema qse_v3 to service_role;
grant usage,select on all sequences in schema qse_v3 to service_role;
revoke all on all functions in schema qse_v3 from public,anon,authenticated;
alter default privileges in schema qse_v3 revoke execute on functions from public;

create function qse_v3.require_user() returns uuid language plpgsql stable security definer set search_path = '' as $$
declare owner uuid := auth.uid();
begin
  if owner is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  return owner;
end $$;
create function qse_v3.ensure_player(owner uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into qse_v3.player_profiles(user_id) values(owner) on conflict do nothing;
  insert into qse_v3.account_preferences(user_id) values(owner) on conflict do nothing;
  insert into qse_v3.player_statistics(user_id) values(owner) on conflict do nothing;
  insert into qse_v3.campaign_progress(user_id) values(owner) on conflict do nothing;
  insert into qse_v3.wallets(user_id) values(owner) on conflict do nothing;
  insert into qse_v3.character_unlocks(user_id,character_id)
    select owner,id from qse_v3.character_catalog where initially_unlocked on conflict do nothing;
  insert into qse_v3.player_loadout values(owner,'cowboy',now()) on conflict do nothing;
end $$;
create function qse_v3.public_fragment(owner uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('user_id',p.user_id,'public_id',p.public_id,'nickname',coalesce(p.nickname,'Sem nickname'),
    'level',s.level,'equipped_character_id',l.equipped_character_id)
  from qse_v3.player_profiles p join qse_v3.player_loadout l using(user_id)
    join qse_v3.player_statistics s using(user_id) where p.user_id = owner
$$;
create function qse_v3.snapshot(owner uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('schema_version',2,'rules_version','desert_progression_2.0.0','player_id',owner,
    'revision',c.revision,'completed_phase_ids',coalesce((select jsonb_agg(p.phase_id order by d.ordinal)
      from qse_v3.phase_completions p join qse_v3.desert_phases d on d.id=p.phase_id where p.user_id=owner),'[]'::jsonb),
    'active_phase_id',c.active_phase_id,'checkpoint',case when c.checkpoint_id is null then null
      else jsonb_build_object('phase_id',c.active_phase_id,'checkpoint_id',c.checkpoint_id) end,
    'achievement_ids',coalesce((select jsonb_agg(a.achievement_id order by a.achievement_id) from qse_v3.player_achievements a where a.user_id=owner),'[]'::jsonb),
    'unlocked_character_ids',coalesce((select jsonb_agg(u.character_id order by array_position(array['cowboy','michelly','rodrigo','lorena','gus','lana','halloween','el_fuego'],u.character_id)) from qse_v3.character_unlocks u where u.user_id=owner),'[]'::jsonb),
    'equipped_character_id',l.equipped_character_id)
  from qse_v3.campaign_progress c join qse_v3.player_loadout l using(user_id) where c.user_id=owner
$$;
commit;
