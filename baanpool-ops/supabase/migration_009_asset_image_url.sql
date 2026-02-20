-- Add image_url column to assets table
ALTER TABLE assets ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Create storage bucket for asset images (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('asset-images', 'asset-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public read access to asset images
CREATE POLICY IF NOT EXISTS "Public read access for asset images"
ON storage.objects FOR SELECT
USING (bucket_id = 'asset-images');

-- Allow authenticated users to upload asset images
CREATE POLICY IF NOT EXISTS "Authenticated upload for asset images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'asset-images' AND auth.role() = 'authenticated');

-- Allow authenticated users to update/delete their asset images
CREATE POLICY IF NOT EXISTS "Authenticated update for asset images"
ON storage.objects FOR UPDATE
USING (bucket_id = 'asset-images' AND auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Authenticated delete for asset images"
ON storage.objects FOR DELETE
USING (bucket_id = 'asset-images' AND auth.role() = 'authenticated');
