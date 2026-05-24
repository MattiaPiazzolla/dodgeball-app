-- supabase/migrations/<timestamp>_add_group_stages.sql
CREATE TABLE public.groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.group_teams (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
  points INT DEFAULT 0,
  wins INT DEFAULT 0,
  losses INT DEFAULT 0,
  UNIQUE(group_id, team_id)
);

ALTER TABLE public.matches
  ADD COLUMN match_type TEXT DEFAULT 'knockout',
  ADD COLUMN group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE;

-- Enable RLS
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_teams ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public read groups" ON public.groups FOR SELECT USING (true);
CREATE POLICY "Auth manage groups" ON public.groups USING (auth.role() = 'authenticated');

CREATE POLICY "Public read group_teams" ON public.group_teams FOR SELECT USING (true);
CREATE POLICY "Auth manage group_teams" ON public.group_teams USING (auth.role() = 'authenticated');
