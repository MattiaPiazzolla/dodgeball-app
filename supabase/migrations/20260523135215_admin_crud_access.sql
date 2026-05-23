-- supabase/migrations/<timestamp>_admin_crud_access.sql
CREATE POLICY "Admins have full access to teams"
  ON public.teams FOR ALL
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins have full access to players"
  ON public.players FOR ALL
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));
