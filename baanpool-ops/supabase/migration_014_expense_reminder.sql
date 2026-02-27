-- =====================================================
-- BaanPool Ops — Migration 014: Daily expense reminder at 17:00
-- Sends LINE notifications for completed work orders
-- that have no expense records.
-- Run this SQL in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- 1. Enable pg_cron extension (Supabase supports this)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 2. Function: find completed work orders without expenses, send LINE reminders
CREATE OR REPLACE FUNCTION public.notify_missing_expenses()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wo RECORD;
  v_property_name TEXT;
  v_message TEXT;
  v_recipient RECORD;
  v_caretaker_id UUID;
BEGIN
  -- Loop through completed work orders that have NO expense records
  FOR v_wo IN
    SELECT wo.id, wo.title, wo.property_id
    FROM public.work_orders wo
    WHERE wo.status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM public.expenses e
        WHERE e.work_order_id = wo.id
      )
  LOOP
    -- Get property name and caretaker
    SELECT name, caretaker_id INTO v_property_name, v_caretaker_id
    FROM public.properties
    WHERE id = v_wo.property_id;

    -- Build message
    v_message := '⚠️ แจ้งเตือนยังไม่บันทึกค่าใช้จ่าย' || chr(10)
      || '📝 ' || v_wo.title || chr(10)
      || '🏠 บ้าน: ' || COALESCE(v_property_name, '-');

    -- Notify caretaker of this property
    IF v_caretaker_id IS NOT NULL THEN
      FOR v_recipient IN
        SELECT line_user_id FROM public.users
        WHERE id = v_caretaker_id
          AND line_user_id IS NOT NULL
          AND line_user_id != ''
      LOOP
        PERFORM public.send_line_text(v_recipient.line_user_id, v_message);
      END LOOP;
    END IF;

    -- Notify all managers/admins/owners
    FOR v_recipient IN
      SELECT DISTINCT line_user_id FROM public.users
      WHERE role IN ('admin', 'owner', 'manager')
        AND line_user_id IS NOT NULL
        AND line_user_id != ''
    LOOP
      PERFORM public.send_line_text(v_recipient.line_user_id, v_message);
    END LOOP;
  END LOOP;
END;
$$;

-- 3. Schedule the cron job to run daily at 17:00 (Bangkok time = UTC+7, so 10:00 UTC)
SELECT cron.schedule(
  'notify-missing-expenses',
  '0 10 * * *',   -- 10:00 UTC = 17:00 Bangkok time
  $$SELECT public.notify_missing_expenses()$$
);

-- =====================================================
-- DONE!
-- The job runs every day at 17:00 (ICT).
-- To check scheduled jobs: SELECT * FROM cron.job;
-- To unschedule: SELECT cron.unschedule('notify-missing-expenses');
-- =====================================================
