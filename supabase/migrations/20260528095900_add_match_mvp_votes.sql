-- supabase/migrations/20260528095900_add_match_mvp_votes.sql

-- 1. Add the match_mvp_votes column to the players table
ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS match_mvp_votes INT DEFAULT 0;

-- 2. Create the increment function for match player votes
CREATE OR REPLACE FUNCTION public.increment_match_player_votes(player_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.players
  SET mvp_votes = COALESCE(mvp_votes, 0) + 1,
      match_mvp_votes = COALESCE(match_mvp_votes, 0) + 1
  WHERE id = player_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the decrement function for match player votes
CREATE OR REPLACE FUNCTION public.decrement_match_player_votes(player_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.players
  SET mvp_votes = GREATEST(0, COALESCE(mvp_votes, 0) - 1),
      match_mvp_votes = GREATEST(0, COALESCE(match_mvp_votes, 0) - 1)
  WHERE id = player_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create a function to reset match_mvp_votes for two specific teams
CREATE OR REPLACE FUNCTION public.reset_match_player_votes(t1_id UUID, t2_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.players
  SET match_mvp_votes = 0
  WHERE team_id = t1_id OR team_id = t2_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
