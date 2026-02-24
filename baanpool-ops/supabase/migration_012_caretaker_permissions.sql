-- =====================================================
-- BaanPool Ops — Migration 012: Fix Caretaker Permissions
-- Allows caretakers to view users (for technician assignment)
-- and manage work orders for their properties.
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- ─── 1. Allow caretakers to view all users (needed for technician dropdown) ─────
DROP POLICY IF EXISTS "Users can view own or admin can view all" ON public.users;
CREATE POLICY "Users can view own or admin can view all"
  ON public.users FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR public.get_user_role() IN ('admin', 'owner', 'manager', 'caretaker')
  );

-- ─── 2. Allow caretakers to view ALL work orders for their properties ─────
-- (migration_004 already added a SELECT policy, but let's ensure it's correct)
DROP POLICY IF EXISTS "Caretaker can view own property work orders" ON public.work_orders;
CREATE POLICY "Caretaker can view own property work orders"
  ON public.work_orders FOR SELECT
  TO authenticated
  USING (
    property_id IN (
      SELECT id FROM public.properties WHERE caretaker_id = auth.uid()
    )
  );

-- ─── 3. Allow caretakers to UPDATE work orders for their properties ─────
DROP POLICY IF EXISTS "Admin or assigned tech can update work orders" ON public.work_orders;
CREATE POLICY "Admin, caretaker or assigned tech can update work orders"
  ON public.work_orders FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid()
    OR public.get_user_role() IN ('admin', 'owner', 'manager')
    OR (
      public.get_user_role() = 'caretaker'
      AND property_id IN (
        SELECT id FROM public.properties WHERE caretaker_id = auth.uid()
      )
    )
  );

-- ─── 4. Allow caretakers to view expenses for their properties ─────
DROP POLICY IF EXISTS "Caretaker can view own property expenses" ON public.expenses;
CREATE POLICY "Caretaker can view own property expenses"
  ON public.expenses FOR SELECT
  TO authenticated
  USING (
    property_id IN (
      SELECT id FROM public.properties WHERE caretaker_id = auth.uid()
    )
  );
