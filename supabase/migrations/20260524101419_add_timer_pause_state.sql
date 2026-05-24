-- supabase/migrations/<timestamp>_add_timer_pause_state.sql
ALTER TABLE public.matches
  ADD COLUMN elapsed_seconds INT DEFAULT 0,
  ADD COLUMN is_timer_running BOOLEAN DEFAULT false;
