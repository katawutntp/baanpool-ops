-- =====================================================
-- BaanPool Ops — Migration 004: Add caretaker role, caretaker_id, line_user_id
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- ─── 1. Add 'caretaker' to users role constraint ─────
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin', 'owner', 'manager', 'caretaker', 'technician'));

-- ─── 2. Add line_user_id to users (for LINE notifications) ─────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS line_user_id TEXT;

CREATE INDEX IF NOT EXISTS idx_users_line_user_id ON public.users(line_user_id);

-- ─── 3. Add caretaker_id to properties ─────
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS caretaker_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_properties_caretaker ON public.properties(caretaker_id);

-- ─── 4. RLS: Caretaker can view properties they manage ─────
DROP POLICY IF EXISTS "Caretaker can view own properties" ON public.properties;
CREATE POLICY "Caretaker can view own properties"
  ON public.properties FOR SELECT
  TO authenticated
  USING (caretaker_id = auth.uid());

-- ─── 5. RLS: Caretaker can view assets of their properties ─────
DROP POLICY IF EXISTS "Caretaker can view own property assets" ON public.assets;
CREATE POLICY "Caretaker can view own property assets"
  ON public.assets FOR SELECT
  TO authenticated
  USING (
    property_id IN (
      SELECT id FROM public.properties WHERE caretaker_id = auth.uid()
    )
  );

-- ─── 6. RLS: Caretaker can view work orders of their properties ─────
DROP POLICY IF EXISTS "Caretaker can view own property work orders" ON public.work_orders;
CREATE POLICY "Caretaker can view own property work orders"
  ON public.work_orders FOR SELECT
  TO authenticated
  USING (
    property_id IN (
      SELECT id FROM public.properties WHERE caretaker_id = auth.uid()
    )
  );

-- ─── 7. Update admin policies to include caretaker management ─────
DROP POLICY IF EXISTS "Admin/Manager+ can manage properties" ON public.properties;
CREATE POLICY "Admin/Manager+ can manage properties"
  ON public.properties FOR ALL
  TO authenticated
  USING (public.get_user_role() IN ('admin', 'owner', 'manager'));
