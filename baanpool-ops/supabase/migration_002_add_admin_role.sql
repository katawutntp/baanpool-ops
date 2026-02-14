-- =====================================================
-- BaanPool Ops — Migration 002: Add Admin Role + Seed Admin User
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- ─── 1. Update role CHECK constraint to include 'admin' ─────
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin', 'owner', 'manager', 'technician'));

-- ─── 2. CRITICAL: Allow users to self-register (insert own row) ─────
-- Without this, new sign-ups cannot create their row in the users table
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile"
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

-- ─── 3. Allow users to update own profile ─────
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

-- ─── 4. Update RLS policies to include 'admin' role ─────

-- Properties
DROP POLICY IF EXISTS "Manager+ can manage properties" ON public.properties;
DROP POLICY IF EXISTS "Admin/Manager+ can manage properties" ON public.properties;
CREATE POLICY "Admin/Manager+ can manage properties"
  ON public.properties FOR ALL
  TO authenticated
  USING (public.get_user_role() IN ('admin', 'owner', 'manager'));

-- Work Orders
DROP POLICY IF EXISTS "Owner/Manager see all work orders" ON public.work_orders;
DROP POLICY IF EXISTS "Admin/Owner/Manager see all work orders" ON public.work_orders;
CREATE POLICY "Admin/Owner/Manager see all work orders"
  ON public.work_orders FOR SELECT
  TO authenticated
  USING (public.get_user_role() IN ('admin', 'owner', 'manager'));

DROP POLICY IF EXISTS "Assigned tech can update own work orders" ON public.work_orders;
DROP POLICY IF EXISTS "Admin or assigned tech can update work orders" ON public.work_orders;
CREATE POLICY "Admin or assigned tech can update work orders"
  ON public.work_orders FOR UPDATE
  TO authenticated
  USING (assigned_to = auth.uid() OR public.get_user_role() IN ('admin', 'owner', 'manager'));

-- Assets
DROP POLICY IF EXISTS "Manager+ can manage assets" ON public.assets;
DROP POLICY IF EXISTS "Admin/Manager+ can manage assets" ON public.assets;
CREATE POLICY "Admin/Manager+ can manage assets"
  ON public.assets FOR ALL
  TO authenticated
  USING (public.get_user_role() IN ('admin', 'owner', 'manager'));

-- Expenses
DROP POLICY IF EXISTS "Owner/Manager see all expenses" ON public.expenses;
DROP POLICY IF EXISTS "Admin/Owner/Manager see all expenses" ON public.expenses;
CREATE POLICY "Admin/Owner/Manager see all expenses"
  ON public.expenses FOR SELECT
  TO authenticated
  USING (public.get_user_role() IN ('admin', 'owner', 'manager'));

-- PM Schedules
DROP POLICY IF EXISTS "Manager+ can manage PM" ON public.pm_schedules;
DROP POLICY IF EXISTS "Admin/Manager+ can manage PM" ON public.pm_schedules;
CREATE POLICY "Admin/Manager+ can manage PM"
  ON public.pm_schedules FOR ALL
  TO authenticated
  USING (public.get_user_role() IN ('admin', 'owner', 'manager'));

-- Users - admin can see + manage all users
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can view own or admin can view all" ON public.users;
CREATE POLICY "Users can view own or admin can view all"
  ON public.users FOR SELECT
  TO authenticated
  USING (id = auth.uid() OR public.get_user_role() IN ('admin', 'owner', 'manager'));

-- Admin can update any user (not just their own)
DROP POLICY IF EXISTS "Admin can update any user" ON public.users;
CREATE POLICY "Admin can update any user"
  ON public.users FOR UPDATE
  TO authenticated
  USING (public.get_user_role() IN ('admin', 'owner', 'manager'));

-- Admin can insert users (for creating new users from admin panel)
DROP POLICY IF EXISTS "Admin can insert users" ON public.users;
CREATE POLICY "Admin can insert users"
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK (public.get_user_role() IN ('admin', 'owner', 'manager') OR id = auth.uid());

-- ─── 5. HOW TO CREATE FIRST ADMIN ─────────────────────
-- The app auto-creates admin for the first user who signs up.
-- If you need to manually set admin, run:
-- UPDATE public.users SET role = 'admin' WHERE email = 'admin@baanpool.ops';
