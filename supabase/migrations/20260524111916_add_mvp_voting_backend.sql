-- supabase/migrations/<timestamp>_add_mvp_voting_backend.sql

-- 1. Ensure the mvp_votes column exists on your players table
ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS mvp_votes INT DEFAULT 0;

-- 2. Create the safe atomic execution function for live fan voting
CREATE OR REPLACE FUNCTION public.increment_player_votes(player_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.players
  SET mvp_votes = COALESCE(mvp_votes, 0) + 1
  WHERE id = player_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
