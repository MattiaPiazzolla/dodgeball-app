-- Admin-controlled tournament registration switch.
create table if not exists public.app_settings (
  id int primary key default 1 check (id = 1),
  registrations_open boolean not null default true,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

insert into public.app_settings (id, registrations_open)
values (1, true)
on conflict (id) do nothing;

alter table public.app_settings enable row level security;

create policy "Public can read app settings"
  on public.app_settings for select
  using (true);

create policy "Admins can update app settings"
  on public.app_settings for update
  using (exists (select 1 from public.users where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.users where id = auth.uid() and role = 'admin'));

create or replace function public.touch_app_settings_updated_at()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

drop trigger if exists app_settings_updated_at on public.app_settings;
create trigger app_settings_updated_at
  before update on public.app_settings
  for each row execute procedure public.touch_app_settings_updated_at();

create or replace function public.enforce_registrations_open()
returns trigger as $$
declare
  is_open boolean;
begin
  select registrations_open into is_open
  from public.app_settings
  where id = 1;

  if coalesce(is_open, true) = false then
    raise exception 'Registrations are currently closed.';
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists block_closed_registrations on auth.users;
create trigger block_closed_registrations
  before insert on auth.users
  for each row execute procedure public.enforce_registrations_open();
