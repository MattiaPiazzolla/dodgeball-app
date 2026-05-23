CREATE POLICY "Admins/Captains Update Logos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'logos')
WITH CHECK (bucket_id = 'logos');

CREATE POLICY "Admins/Captains Update Photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'player-photos')
WITH CHECK (bucket_id = 'player-photos');
