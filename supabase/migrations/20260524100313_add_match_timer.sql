-- supabase/migrations/<timestamp>_add_match_timer.sql
ALTER TABLE public.matches
  ADD COLUMN timer_started_at TIMESTAMPTZ DEFAULT NULL;
