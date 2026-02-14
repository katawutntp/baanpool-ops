-- =====================================================
-- BaanPool Ops — Supabase Database Migration
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── 1. USERS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'technician' CHECK (role IN ('owner', 'manager', 'technician')),
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 2. PROPERTIES ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.properties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  owner_name TEXT,
  owner_contact TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 3. ASSETS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT,
  brand TEXT,
  model TEXT,
  install_date DATE,
  warranty_expiry DATE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 4. WORK ORDERS ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.work_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  asset_id UUID REFERENCES public.assets(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  due_date TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  photo_urls TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 5. EXPENSES ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  work_order_id UUID NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  amount NUMERIC(12,2) NOT NULL,
  description TEXT,
  category TEXT,
  receipt_url TEXT,
  billable_to_partner BOOLEAN DEFAULT FALSE,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 6. PM SCHEDULES ───────────────────────────────
CREATE TABLE IF NOT EXISTS public.pm_schedules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  asset_id UUID REFERENCES public.assets(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  frequency TEXT NOT NULL DEFAULT 'monthly' CHECK (frequency IN ('weekly', 'biweekly', 'monthly', 'quarterly', 'semiannual', 'annual')),
  next_due_date DATE NOT NULL,
  last_completed_date DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── ROW LEVEL SECURITY ────────────────────────────

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pm_schedules ENABLE ROW LEVEL SECURITY;

-- Owner & Manager: เห็นทุกข้อมูล
-- Technician: เห็นเฉพาะงานตัวเอง

-- Helper function: get current user role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER;

-- Properties: ทุกคนเห็นได้
CREATE POLICY "All authenticated users can view properties"
  ON public.properties FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Manager+ can manage properties"
  ON public.properties FOR ALL
  TO authenticated
  USING (public.get_user_role() IN ('owner', 'manager'));

-- Work Orders: Technician เห็นเฉพาะงานตัวเอง
CREATE POLICY "Owner/Manager see all work orders"
  ON public.work_orders FOR SELECT
  TO authenticated
  USING (public.get_user_role() IN ('owner', 'manager'));

CREATE POLICY "Technician sees own work orders"
  ON public.work_orders FOR SELECT
  TO authenticated
  USING (assigned_to = auth.uid());

CREATE POLICY "Authenticated can create work orders"
  ON public.work_orders FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Assigned tech can update own work orders"
  ON public.work_orders FOR UPDATE
  TO authenticated
  USING (assigned_to = auth.uid() OR public.get_user_role() IN ('owner', 'manager'));

-- Assets: ทุกคนเห็นได้
CREATE POLICY "All authenticated users can view assets"
  ON public.assets FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Manager+ can manage assets"
  ON public.assets FOR ALL
  TO authenticated
  USING (public.get_user_role() IN ('owner', 'manager'));

-- Expenses: เหมือน work orders
CREATE POLICY "Owner/Manager see all expenses"
  ON public.expenses FOR SELECT
  TO authenticated
  USING (public.get_user_role() IN ('owner', 'manager'));

CREATE POLICY "Authenticated can create expenses"
  ON public.expenses FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- PM Schedules: ทุกคนดูได้
CREATE POLICY "All authenticated can view PM"
  ON public.pm_schedules FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Manager+ can manage PM"
  ON public.pm_schedules FOR ALL
  TO authenticated
  USING (public.get_user_role() IN ('owner', 'manager'));

-- Users: ดูตัวเองได้
CREATE POLICY "Users can view own profile"
  ON public.users FOR SELECT
  TO authenticated
  USING (id = auth.uid() OR public.get_user_role() IN ('owner', 'manager'));

-- ─── INDEXES ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_work_orders_status ON public.work_orders(status);
CREATE INDEX IF NOT EXISTS idx_work_orders_property ON public.work_orders(property_id);
CREATE INDEX IF NOT EXISTS idx_work_orders_assigned ON public.work_orders(assigned_to);
CREATE INDEX IF NOT EXISTS idx_expenses_work_order ON public.expenses(work_order_id);
CREATE INDEX IF NOT EXISTS idx_assets_property ON public.assets(property_id);
CREATE INDEX IF NOT EXISTS idx_pm_schedules_next_due ON public.pm_schedules(next_due_date);
