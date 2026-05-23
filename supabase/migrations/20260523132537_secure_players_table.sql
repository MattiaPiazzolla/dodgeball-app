-- supabase/migrations/<timestamp>_secure_players_table.sql
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public Read Players"
  ON public.players FOR SELECT
  USING (true);

CREATE POLICY "Captains manage own players"
  ON public.players FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.teams
    WHERE teams.id = players.team_id AND teams.captain_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.teams
    WHERE teams.id = players.team_id AND teams.captain_id = auth.uid()
  ));
