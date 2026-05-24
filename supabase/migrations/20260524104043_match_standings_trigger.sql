-- supabase/migrations/20260524104043_match_standings_trigger.sql

-- 1. Add the missing winner_id column
ALTER TABLE public.matches
ADD COLUMN IF NOT EXISTS winner_id UUID REFERENCES public.teams(id) ON DELETE SET NULL;

-- 2. Create the standings calculation function
CREATE OR REPLACE FUNCTION recalculate_group_standings()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.match_type = 'group' THEN
    -- Recalculate for Team 1
    IF NEW.team1_id IS NOT NULL THEN
        UPDATE public.group_teams
        SET
          wins = (SELECT count(*) FROM public.matches WHERE group_id = NEW.group_id AND match_type = 'group' AND status IN ('completed', 'retired') AND winner_id = NEW.team1_id),
          losses = (SELECT count(*) FROM public.matches WHERE group_id = NEW.group_id AND match_type = 'group' AND status IN ('completed', 'retired') AND winner_id IS NOT NULL AND winner_id != NEW.team1_id AND (team1_id = NEW.team1_id OR team2_id = NEW.team1_id)),
          points = (SELECT count(*) FROM public.matches WHERE group_id = NEW.group_id AND match_type = 'group' AND status IN ('completed', 'retired') AND winner_id = NEW.team1_id) * 3
        WHERE group_id = NEW.group_id AND team_id = NEW.team1_id;
    END IF;

    -- Recalculate for Team 2
    IF NEW.team2_id IS NOT NULL THEN
        UPDATE public.group_teams
        SET
          wins = (SELECT count(*) FROM public.matches WHERE group_id = NEW.group_id AND match_type = 'group' AND status IN ('completed', 'retired') AND winner_id = NEW.team2_id),
          losses = (SELECT count(*) FROM public.matches WHERE group_id = NEW.group_id AND match_type = 'group' AND status IN ('completed', 'retired') AND winner_id IS NOT NULL AND winner_id != NEW.team2_id AND (team1_id = NEW.team2_id OR team2_id = NEW.team2_id)),
          points = (SELECT count(*) FROM public.matches WHERE group_id = NEW.group_id AND match_type = 'group' AND status IN ('completed', 'retired') AND winner_id = NEW.team2_id) * 3
        WHERE group_id = NEW.group_id AND team_id = NEW.team2_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Apply the trigger
DROP TRIGGER IF EXISTS trigger_update_group_standings ON public.matches;
CREATE TRIGGER trigger_update_group_standings
AFTER UPDATE OF status, winner_id ON public.matches
FOR EACH ROW
EXECUTE FUNCTION recalculate_group_standings();
