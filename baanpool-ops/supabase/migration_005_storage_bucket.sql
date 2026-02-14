-- =====================================================
-- BaanPool Ops — Storage Bucket Setup
-- =====================================================
-- 
-- STEP 1: Go to Supabase Dashboard → Storage → Create new bucket
--   Bucket name: photos
--   Public bucket: YES (check the box)
--
-- STEP 2: Run this SQL to set storage policies
-- =====================================================

-- Allow authenticated users to upload files
CREATE POLICY "Allow authenticated upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'photos');

-- Allow authenticated users to update their files
CREATE POLICY "Allow authenticated update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'photos');

-- Allow public read access (for viewing photos)
CREATE POLICY "Allow public read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'photos');

-- Allow authenticated users to delete files
CREATE POLICY "Allow authenticated delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'photos');
