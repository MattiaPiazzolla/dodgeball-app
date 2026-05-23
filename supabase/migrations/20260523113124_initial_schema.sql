-- supabase/migrations/<timestamp>_initial_schema.sql
create table public.users (
  id uuid references auth.users not null primary key,
  role text check (role in ('admin', 'captain')) default 'captain',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.teams (
  id uuid default gen_random_uuid() primary key,
  captain_id uuid references public.users(id) not null,
  name text not null,
  logo_url text,
  is_approved boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.players (
  id uuid default gen_random_uuid() primary key,
  team_id uuid references public.teams(id) on delete cascade not null,
  name text not null,
  photo_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.matches (
  id uuid default gen_random_uuid() primary key,
  team1_id uuid references public.teams(id),
  team2_id uuid references public.teams(id),
  team1_score int default 0,
  team2_score int default 0,
  status text default 'scheduled',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.votes (
  id uuid default gen_random_uuid() primary key,
  match_id uuid references public.matches(id) on delete cascade not null,
  player_id uuid references public.players(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
