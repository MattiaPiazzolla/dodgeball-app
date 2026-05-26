-- supabase/migrations/20260526144000_add_decrement_vote.sql

-- Create a safe atomic execution function for live fan voting removal
CREATE OR REPLACE FUNCTION public.decrement_player_votes(player_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.players
  SET mvp_votes = GREATEST(COALESCE(mvp_votes, 0) - 1, 0)
  WHERE id = player_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
