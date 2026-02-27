-- =====================================================
-- BaanPool Ops — Migration 013: Allow caretakers to add/edit assets
-- Caretakers can INSERT and UPDATE assets for their own properties.
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- ─── 1. Allow caretakers to INSERT assets for their properties ─────
DROP POLICY IF EXISTS "Caretaker can insert assets for own properties" ON public.assets;
CREATE POLICY "Caretaker can insert assets for own properties"
  ON public.assets FOR INSERT
  TO authenticated
  WITH CHECK (
    public.get_user_role() = 'caretaker'
    AND property_id IN (
      SELECT id FROM public.properties WHERE caretaker_id = auth.uid()
    )
  );

-- ─── 2. Allow caretakers to UPDATE assets for their properties ─────
DROP POLICY IF EXISTS "Caretaker can update assets for own properties" ON public.assets;
CREATE POLICY "Caretaker can update assets for own properties"
  ON public.assets FOR UPDATE
  TO authenticated
  USING (
    public.get_user_role() = 'caretaker'
    AND property_id IN (
      SELECT id FROM public.properties WHERE caretaker_id = auth.uid()
    )
  );
