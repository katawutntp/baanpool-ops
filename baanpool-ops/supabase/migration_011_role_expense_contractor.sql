-- =====================================================
-- BaanPool Ops — Migration 011: Role hierarchy, expense cost separation, contractors
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- ─── 1. Add cost_type to expenses (PM vs work_order) ─────
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS cost_type TEXT DEFAULT 'work_order'
  CHECK (cost_type IN ('work_order', 'pm'));

-- ─── 2. Add paid_by to expenses (company vs owner) ─────
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS paid_by TEXT DEFAULT 'company'
  CHECK (paid_by IN ('company', 'owner'));

-- ─── 3. Make work_order_id nullable (PM expenses may not have a work order) ─────
ALTER TABLE public.expenses
  ALTER COLUMN work_order_id DROP NOT NULL;

-- ─── 4. Add pm_schedule_id to expenses (for PM cost tracking) ─────
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS pm_schedule_id UUID REFERENCES public.pm_schedules(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_expenses_pm_schedule ON public.expenses(pm_schedule_id);
CREATE INDEX IF NOT EXISTS idx_expenses_cost_type ON public.expenses(cost_type);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON public.expenses(paid_by);

-- ─── 5. Create contractors table ─────
CREATE TABLE IF NOT EXISTS public.contractors (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  specialty TEXT,           -- เช่น ไฟฟ้า, ประปา, แอร์, ทั่วไป
  company_name TEXT,
  notes TEXT,
  rating SMALLINT CHECK (rating >= 1 AND rating <= 5),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contractors_specialty ON public.contractors(specialty);
CREATE INDEX IF NOT EXISTS idx_contractors_active ON public.contractors(is_active);

-- ─── 6. Create contractor_history table (job history) ─────
CREATE TABLE IF NOT EXISTS public.contractor_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contractor_id UUID NOT NULL REFERENCES public.contractors(id) ON DELETE CASCADE,
  work_order_id UUID REFERENCES public.work_orders(id) ON DELETE SET NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  description TEXT,
  amount NUMERIC(12,2),
  work_date DATE,
  rating SMALLINT CHECK (rating >= 1 AND rating <= 5),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contractor_history_contractor ON public.contractor_history(contractor_id);
CREATE INDEX IF NOT EXISTS idx_contractor_history_work_order ON public.contractor_history(work_order_id);

-- ─── 7. RLS for contractors ─────
ALTER TABLE public.contractors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contractor_history ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view contractors
DROP POLICY IF EXISTS "Authenticated users can view contractors" ON public.contractors;
CREATE POLICY "Authenticated users can view contractors"
  ON public.contractors FOR SELECT
  TO authenticated
  USING (true);

-- Admin/manager/caretaker can manage contractors
DROP POLICY IF EXISTS "Admins can manage contractors" ON public.contractors;
CREATE POLICY "Admins can manage contractors"
  ON public.contractors FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('admin', 'owner', 'manager', 'caretaker')
    )
  );

-- All authenticated users can view contractor history
DROP POLICY IF EXISTS "Authenticated users can view contractor history" ON public.contractor_history;
CREATE POLICY "Authenticated users can view contractor history"
  ON public.contractor_history FOR SELECT
  TO authenticated
  USING (true);

-- Admin/manager/caretaker can manage contractor history
DROP POLICY IF EXISTS "Admins can manage contractor history" ON public.contractor_history;
CREATE POLICY "Admins can manage contractor history"
  ON public.contractor_history FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('admin', 'owner', 'manager', 'caretaker')
    )
  );
