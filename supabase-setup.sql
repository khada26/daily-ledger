-- Daily Ledger sync setup.
-- In Supabase: open SQL Editor > New query, paste this whole file, then press Run.

create table if not exists public.entries (
  user_id    uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  id         text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at bigint      not null default 0,
  deleted    boolean     not null default false,
  synced_at  timestamptz not null default clock_timestamp(),
  primary key (user_id, id)
);

create table if not exists public.settings (
  user_id    uuid        primary key default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb       not null default '{}'::jsonb,
  updated_at bigint      not null default 0,
  synced_at  timestamptz not null default clock_timestamp()
);

create index if not exists entries_user_synced_idx on public.entries (user_id, synced_at);

-- The server stamps every write, so devices with wrong clocks can still catch up.
create or replace function public.touch_synced_at() returns trigger
language plpgsql as $$
begin
  new.synced_at := clock_timestamp();
  return new;
end $$;

drop trigger if exists entries_touch on public.entries;
create trigger entries_touch before insert or update on public.entries
  for each row execute function public.touch_synced_at();

drop trigger if exists settings_touch on public.settings;
create trigger settings_touch before insert or update on public.settings
  for each row execute function public.touch_synced_at();

-- Each person can only see and change their own rows.
alter table public.entries  enable row level security;
alter table public.settings enable row level security;

drop policy if exists "own entries"  on public.entries;
drop policy if exists "own settings" on public.settings;
create policy "own entries"  on public.entries  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own settings" on public.settings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());


-- Lets a signed-in user permanently delete their own account.
-- Entries and settings are removed too (on delete cascade).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
