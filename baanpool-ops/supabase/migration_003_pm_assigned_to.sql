-- =====================================================
-- BaanPool Ops — Migration 003: Add assigned_to to PM Schedules
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- Add assigned_to column to pm_schedules (technician assignment)
ALTER TABLE public.pm_schedules
  ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL;

-- Index for faster lookup by assigned technician
CREATE INDEX IF NOT EXISTS idx_pm_schedules_assigned ON public.pm_schedules(assigned_to);

-- Allow technicians to see PM schedules assigned to them
DROP POLICY IF EXISTS "Technician sees own PM schedules" ON public.pm_schedules;
CREATE POLICY "Technician sees own PM schedules"
  ON public.pm_schedules FOR SELECT
  TO authenticated
  USING (assigned_to = auth.uid());
