-- supabase/migrations/<timestamp>_fix_matches_rls.sql
DROP POLICY IF EXISTS "Matches viewable by everyone" ON public.matches;
DROP POLICY IF EXISTS "Auth users can insert matches" ON public.matches;
DROP POLICY IF EXISTS "Auth users can update matches" ON public.matches;

CREATE POLICY "Enable read access for all users" ON public.matches FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON public.matches FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON public.matches FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Enable delete for authenticated users" ON public.matches FOR DELETE TO authenticated USING (true);
