-- supabase/migrations/<timestamp>_update_matches_schema.sql
ALTER TABLE public.matches
  DROP COLUMN IF EXISTS scheduled_time,
  ADD COLUMN start_time TIME,
  ADD COLUMN round INT DEFAULT 1;
