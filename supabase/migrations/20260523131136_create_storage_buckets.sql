-- supabase/migrations/<your_timestamp>_create_storage_buckets.sql

-- Create buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('logos', 'logos', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('player-photos', 'player-photos', true);

-- Policies for logos
CREATE POLICY "Public Read Logos" ON storage.objects FOR SELECT USING (bucket_id = 'logos');
CREATE POLICY "Captains Upload Logos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'logos' AND auth.role() = 'authenticated');

-- Policies for player-photos
CREATE POLICY "Public Read Photos" ON storage.objects FOR SELECT USING (bucket_id = 'player-photos');
CREATE POLICY "Captains Upload Photos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'player-photos' AND auth.role() = 'authenticated');
