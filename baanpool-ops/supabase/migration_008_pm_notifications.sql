-- =====================================================
-- BaanPool Ops — PM Schedule Notifications (LINE + In-App)
-- =====================================================
-- This migration adds:
-- 1. A cron-based function to check PM schedules due within 7 days
-- 2. LINE notifications to technician + property manager for PM
-- 3. In-app notifications for PM due/overdue
-- 4. Trigger on pm_schedules to notify when next_due_date is set/changed
--
-- Run this SQL in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. Function: notify PM due (LINE + In-App)
--    Called for each PM schedule that is due soon or overdue
-- =====================================================
CREATE OR REPLACE FUNCTION public.notify_pm_due(
  p_pm_id UUID,
  p_pm_title TEXT,
  p_property_id UUID,
  p_assigned_to UUID,
  p_next_due_date DATE,
  p_description TEXT DEFAULT NULL,
  p_asset_id UUID DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_property_name TEXT;
  v_caretaker_id UUID;
  v_tech_name TEXT;
  v_tech_line_id TEXT;
  v_caretaker_line_id TEXT;
  v_days_until_due INT;
  v_status_text TEXT;
  v_emoji TEXT;
  v_message TEXT;
  v_body TEXT;
  v_recipient RECORD;
BEGIN
  -- Calculate days until due
  v_days_until_due := p_next_due_date - CURRENT_DATE;

  -- Only notify if due within 7 days or overdue
  IF v_days_until_due > 7 THEN
    RETURN;
  END IF;

  -- Get property info
  SELECT name, caretaker_id INTO v_property_name, v_caretaker_id
  FROM public.properties
  WHERE id = p_property_id;

  -- Status text
  IF v_days_until_due < 0 THEN
    v_status_text := '⚠️ เกินกำหนด ' || (-v_days_until_due) || ' วัน';
    v_emoji := '🔴';
  ELSIF v_days_until_due = 0 THEN
    v_status_text := '⏰ ถึงกำหนดวันนี้';
    v_emoji := '🔴';
  ELSE
    v_status_text := '⏰ อีก ' || v_days_until_due || ' วัน';
    v_emoji := '🟡';
  END IF;

  -- Build LINE message
  v_message := v_emoji || ' แจ้งเตือน PM' || chr(10)
    || '📋 ' || p_pm_title || chr(10)
    || '🏠 บ้าน: ' || COALESCE(v_property_name, '-') || chr(10)
    || CASE WHEN p_description IS NOT NULL AND p_description != ''
         THEN '📝 รายละเอียด: ' || p_description || chr(10)
         ELSE '' END
    || '📅 กำหนด: ' || to_char(p_next_due_date, 'DD/MM/YYYY') || chr(10)
    || v_status_text || chr(10)
    || CASE WHEN p_asset_id IS NOT NULL
         THEN '🔗 https://changyai.vercel.app/assets/' || p_asset_id::TEXT
         ELSE '' END;

  -- Build in-app notification body
  v_body := '🏠 บ้าน: ' || COALESCE(v_property_name, '-') || chr(10)
    || '📅 กำหนด: ' || to_char(p_next_due_date, 'DD/MM/YYYY') || chr(10)
    || v_status_text;

  -- ─── Notify assigned technician ───
  IF p_assigned_to IS NOT NULL THEN
    -- Get technician info
    SELECT full_name, line_user_id
    INTO v_tech_name, v_tech_line_id
    FROM public.users
    WHERE id = p_assigned_to;

    -- LINE notification to technician
    IF v_tech_line_id IS NOT NULL AND v_tech_line_id != '' THEN
      PERFORM public.send_line_text(v_tech_line_id, v_message);
    END IF;

    -- In-app notification to technician
    INSERT INTO public.notifications (user_id, title, body, type, reference_id)
    VALUES (
      p_assigned_to,
      v_emoji || ' PM: ' || p_pm_title,
      v_body,
      'pm',
      p_pm_id::TEXT
    );
  END IF;

  -- ─── Notify property manager (caretaker_id) ───
  IF v_caretaker_id IS NOT NULL THEN
    SELECT line_user_id INTO v_caretaker_line_id
    FROM public.users
    WHERE id = v_caretaker_id;

    -- LINE notification to property manager
    IF v_caretaker_line_id IS NOT NULL AND v_caretaker_line_id != '' THEN
      PERFORM public.send_line_text(v_caretaker_line_id, v_message);
    END IF;

    -- In-app notification to property manager
    INSERT INTO public.notifications (user_id, title, body, type, reference_id)
    VALUES (
      v_caretaker_id,
      v_emoji || ' PM: ' || p_pm_title,
      v_body,
      'pm',
      p_pm_id::TEXT
    );
  END IF;

  -- ─── Notify all admin/owner/manager users ───
  FOR v_recipient IN
    SELECT DISTINCT id, line_user_id FROM public.users
    WHERE role IN ('admin', 'owner', 'manager')
      AND id != COALESCE(p_assigned_to, '00000000-0000-0000-0000-000000000000'::UUID)
      AND id != COALESCE(v_caretaker_id, '00000000-0000-0000-0000-000000000000'::UUID)
  LOOP
    -- LINE notification
    IF v_recipient.line_user_id IS NOT NULL AND v_recipient.line_user_id != '' THEN
      PERFORM public.send_line_text(v_recipient.line_user_id, v_message);
    END IF;

    -- In-app notification
    INSERT INTO public.notifications (user_id, title, body, type, reference_id)
    VALUES (
      v_recipient.id,
      v_emoji || ' PM: ' || p_pm_title,
      v_body,
      'pm',
      p_pm_id::TEXT
    );
  END LOOP;
END;
$$;

-- =====================================================
-- 2. Function: batch check all PM schedules due within 7 days
--    This can be called by pg_cron or manually
-- =====================================================
CREATE OR REPLACE FUNCTION public.check_pm_due_schedules()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pm RECORD;
  v_count INT := 0;
BEGIN
  FOR v_pm IN
    SELECT id, title, property_id, assigned_to, next_due_date, description, asset_id
    FROM public.pm_schedules
    WHERE is_active = true
      AND next_due_date <= (CURRENT_DATE + INTERVAL '7 days')
  LOOP
    PERFORM public.notify_pm_due(
      v_pm.id,
      v_pm.title,
      v_pm.property_id,
      v_pm.assigned_to,
      v_pm.next_due_date,
      v_pm.description,
      v_pm.asset_id
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- =====================================================
-- 3. Trigger: notify when PM schedule is created or 
--    next_due_date is updated and is within 7 days
-- =====================================================
CREATE OR REPLACE FUNCTION public.trg_pm_schedule_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- On INSERT: notify if due within 7 days
  IF TG_OP = 'INSERT' THEN
    IF NEW.is_active AND NEW.next_due_date <= (CURRENT_DATE + INTERVAL '7 days') THEN
      PERFORM public.notify_pm_due(
        NEW.id, NEW.title, NEW.property_id, NEW.assigned_to, NEW.next_due_date, NEW.description, NEW.asset_id
      );
    END IF;
    RETURN NEW;
  END IF;

  -- On UPDATE: notify if next_due_date changed and now within 7 days
  IF TG_OP = 'UPDATE' THEN
    -- If next_due_date changed or assigned_to changed
    IF (NEW.next_due_date IS DISTINCT FROM OLD.next_due_date
        OR NEW.assigned_to IS DISTINCT FROM OLD.assigned_to)
       AND NEW.is_active
       AND NEW.next_due_date <= (CURRENT_DATE + INTERVAL '7 days') THEN
      PERFORM public.notify_pm_due(
        NEW.id, NEW.title, NEW.property_id, NEW.assigned_to, NEW.next_due_date, NEW.description, NEW.asset_id
      );
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pm_schedule_notify ON public.pm_schedules;
CREATE TRIGGER trg_pm_schedule_notify
  AFTER INSERT OR UPDATE OF next_due_date, assigned_to, is_active ON public.pm_schedules
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_pm_schedule_notify();

-- =====================================================
-- 4. Enable pg_cron for daily PM check (if available)
--    This runs check_pm_due_schedules() every day at 8:00 AM
--    NOTE: pg_cron may need to be enabled in Supabase Dashboard
--    under Database > Extensions
-- =====================================================
-- Uncomment the following after enabling pg_cron extension:
--
-- CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
--
-- SELECT cron.schedule(
--   'daily-pm-check',
--   '0 8 * * *',  -- Every day at 8:00 AM UTC (adjust for your timezone)
--   $$SELECT public.check_pm_due_schedules()$$
-- );
--
-- To run manually for testing:
-- SELECT public.check_pm_due_schedules();

-- =====================================================
-- DONE! PM notifications are now active for:
-- - Assigned technician (LINE + in-app)
-- - Property manager/caretaker (LINE + in-app)
-- - All admin/owner/manager users (LINE + in-app)
--
-- Triggers fire on:
-- - PM schedule created with due date within 7 days
-- - PM schedule due date or assignment changed
--
-- For daily automatic checks, enable pg_cron above.
-- Or call check_pm_due_schedules() from the app.
-- =====================================================
