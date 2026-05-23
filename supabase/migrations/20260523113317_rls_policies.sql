-- supabase/migrations/<timestamp>_rls_policies.sql

alter table public.users enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.votes enable row level security;

create policy "Users can read own data" on public.users for select using (auth.uid() = id);

create policy "Public can read approved teams" on public.teams for select using (is_approved = true);
create policy "Captains can manage own teams" on public.teams for all using (auth.uid() = captain_id);

create policy "Public can read players" on public.players for select using (true);
create policy "Captains can manage team players" on public.players for all using (
  team_id in (select id from public.teams where captain_id = auth.uid())
);

create policy "Public can read matches" on public.matches for select using (true);

create policy "Public can read votes" on public.votes for select using (true);
create policy "Public can insert votes" on public.votes for insert with check (true);
