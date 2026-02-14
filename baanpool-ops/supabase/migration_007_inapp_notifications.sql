-- =====================================================
-- BaanPool Ops — In-App Notifications Table
-- =====================================================
-- Run this SQL in Supabase SQL Editor
-- =====================================================

-- Notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info', -- info, work_order, pm, expense
  reference_id TEXT, -- e.g. work_order id
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_notifications_user_id 
  ON public.notifications(user_id, is_read, created_at DESC);

-- RLS: users can only see their own notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own notifications" ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users update own notifications" ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

-- Allow triggers (SECURITY DEFINER) to insert for any user
CREATE POLICY "System insert notifications" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- =====================================================
-- Enable Realtime on notifications table
-- =====================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- =====================================================
-- Trigger: create in-app notification when work order assigned
-- =====================================================
CREATE OR REPLACE FUNCTION public.trg_inapp_notify_work_order_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_property_name TEXT;
  v_priority_label TEXT;
BEGIN
  -- Only fire when assigned_to is set (new or changed)
  IF TG_OP = 'INSERT' THEN
    IF NEW.assigned_to IS NULL THEN RETURN NEW; END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.assigned_to IS NOT DISTINCT FROM OLD.assigned_to THEN RETURN NEW; END IF;
    IF NEW.assigned_to IS NULL THEN RETURN NEW; END IF;
  END IF;

  SELECT name INTO v_property_name FROM public.properties WHERE id = NEW.property_id;

  CASE COALESCE(NEW.priority, 'medium')
    WHEN 'urgent' THEN v_priority_label := 'เร่งด่วน';
    WHEN 'high'   THEN v_priority_label := 'สูง';
    WHEN 'medium' THEN v_priority_label := 'ปานกลาง';
    WHEN 'low'    THEN v_priority_label := 'ต่ำ';
    ELSE               v_priority_label := NEW.priority;
  END CASE;

  -- Notify technician
  INSERT INTO public.notifications (user_id, title, body, type, reference_id)
  VALUES (
    NEW.assigned_to,
    '📢 งานใหม่: ' || NEW.title,
    '🏠 บ้าน: ' || COALESCE(v_property_name, '-') || chr(10) 
      || '🔧 ความสำคัญ: ' || v_priority_label,
    'work_order',
    NEW.id::TEXT
  );

  RETURN NEW;
END;
$$;

-- =====================================================
-- Trigger: create in-app notification on status change
-- =====================================================
CREATE OR REPLACE FUNCTION public.trg_inapp_notify_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_property RECORD;
  v_tech_name TEXT;
  v_status_text TEXT;
  v_emoji TEXT;
  v_body TEXT;
  v_recipient RECORD;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;

  SELECT name, caretaker_id INTO v_property FROM public.properties WHERE id = NEW.property_id;

  IF NEW.assigned_to IS NOT NULL THEN
    SELECT full_name INTO v_tech_name FROM public.users WHERE id = NEW.assigned_to;
  END IF;

  CASE NEW.status
    WHEN 'open'        THEN v_status_text := 'เปิด';           v_emoji := '🆕';
    WHEN 'in_progress' THEN v_status_text := 'กำลังดำเนินการ'; v_emoji := '🔄';
    WHEN 'completed'   THEN v_status_text := 'เสร็จแล้ว';      v_emoji := '✅';
    WHEN 'cancelled'   THEN v_status_text := 'ยกเลิก';         v_emoji := '❌';
    ELSE                    v_status_text := NEW.status;        v_emoji := '📋';
  END CASE;

  v_body := '🏠 บ้าน: ' || COALESCE(v_property.name, '-') || chr(10)
    || '📊 สถานะ: ' || v_status_text
    || CASE WHEN v_tech_name IS NOT NULL THEN chr(10) || '👷 ช่าง: ' || v_tech_name ELSE '' END;

  -- Notify caretaker
  IF v_property.caretaker_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, reference_id)
    VALUES (v_property.caretaker_id, v_emoji || ' ' || NEW.title, v_body, 'work_order', NEW.id::TEXT);
  END IF;

  -- Notify managers/admins/owners
  FOR v_recipient IN
    SELECT DISTINCT id FROM public.users
    WHERE role IN ('admin', 'owner', 'manager')
      AND id != COALESCE(v_property.caretaker_id, '00000000-0000-0000-0000-000000000000'::UUID)
  LOOP
    INSERT INTO public.notifications (user_id, title, body, type, reference_id)
    VALUES (v_recipient.id, v_emoji || ' ' || NEW.title, v_body, 'work_order', NEW.id::TEXT);
  END LOOP;

  RETURN NEW;
END;
$$;

-- =====================================================
-- Create the in-app triggers
-- =====================================================
DROP TRIGGER IF EXISTS trg_inapp_work_order_assigned ON public.work_orders;
CREATE TRIGGER trg_inapp_work_order_assigned
  AFTER INSERT OR UPDATE OF assigned_to ON public.work_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_inapp_notify_work_order_assigned();

DROP TRIGGER IF EXISTS trg_inapp_work_order_status ON public.work_orders;
CREATE TRIGGER trg_inapp_work_order_status
  AFTER UPDATE OF status ON public.work_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_inapp_notify_status_change();
