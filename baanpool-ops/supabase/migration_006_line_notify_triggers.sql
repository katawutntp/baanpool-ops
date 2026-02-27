-- =====================================================
-- BaanPool Ops — LINE Notification via Database Triggers
-- =====================================================
--
-- This migration creates server-side LINE push notifications
-- using PostgreSQL triggers + pg_net extension.
--
-- Flutter Web cannot call LINE API directly (CORS blocked),
-- so we send notifications from the database instead.
--
-- STEP 1: Run this entire SQL in Supabase SQL Editor
-- STEP 2: Update the LINE token in app_settings table:
--   UPDATE app_settings SET value = 'YOUR_REAL_TOKEN' WHERE key = 'line_messaging_token';
--
-- =====================================================

-- 1. Enable pg_net extension (for HTTP calls from PG)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- 2. Settings table to store LINE Messaging API token
CREATE TABLE IF NOT EXISTS public.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: only authenticated can read, nobody can write from client
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read" ON public.app_settings
  FOR SELECT TO authenticated USING (true);

-- 3. Insert placeholder token (update after running migration)
INSERT INTO public.app_settings (key, value) VALUES
  ('line_messaging_token', 'REPLACE_WITH_YOUR_TOKEN')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- 4. Function: send LINE push message via pg_net
-- =====================================================
CREATE OR REPLACE FUNCTION public.send_line_push(
  p_line_user_id TEXT,
  p_message_json JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token TEXT;
BEGIN
  -- Get the LINE Messaging API token
  SELECT value INTO v_token
  FROM public.app_settings
  WHERE key = 'line_messaging_token';

  IF v_token IS NULL OR v_token = '' OR v_token = 'REPLACE_WITH_YOUR_TOKEN' THEN
    RAISE NOTICE 'LINE token not configured in app_settings';
    RETURN;
  END IF;

  IF p_line_user_id IS NULL OR p_line_user_id = '' THEN
    RETURN;
  END IF;

  -- Send HTTP POST via pg_net
  PERFORM net.http_post(
    url := 'https://api.line.me/v2/bot/message/push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_token
    ),
    body := jsonb_build_object(
      'to', p_line_user_id,
      'messages', p_message_json
    )
  );
END;
$$;

-- =====================================================
-- 5. Helper: send a simple text push
-- =====================================================
CREATE OR REPLACE FUNCTION public.send_line_text(
  p_line_user_id TEXT,
  p_message TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.send_line_push(
    p_line_user_id,
    jsonb_build_array(
      jsonb_build_object('type', 'text', 'text', p_message)
    )
  );
END;
$$;

-- =====================================================
-- 6. Helper: send a flex message push
-- =====================================================
CREATE OR REPLACE FUNCTION public.send_line_flex(
  p_line_user_id TEXT,
  p_alt_text TEXT,
  p_flex_contents JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.send_line_push(
    p_line_user_id,
    jsonb_build_array(
      jsonb_build_object(
        'type', 'flex',
        'altText', p_alt_text,
        'contents', p_flex_contents
      )
    )
  );
END;
$$;

-- =====================================================
-- 7. Trigger: notify technician on work order assignment
-- =====================================================
CREATE OR REPLACE FUNCTION public.trg_notify_work_order_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_line_user_id TEXT;
  v_tech_name TEXT;
  v_property_name TEXT;
  v_priority_label TEXT;
  v_priority_emoji TEXT;
  v_flex JSONB;
BEGIN
  -- Only fire when assigned_to is set (new or changed)
  IF TG_OP = 'INSERT' THEN
    IF NEW.assigned_to IS NULL THEN
      RETURN NEW;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.assigned_to IS NOT DISTINCT FROM OLD.assigned_to THEN
      RETURN NEW;
    END IF;
    IF NEW.assigned_to IS NULL THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Get technician LINE user ID
  SELECT line_user_id, full_name
  INTO v_line_user_id, v_tech_name
  FROM public.users
  WHERE id = NEW.assigned_to;

  IF v_line_user_id IS NULL OR v_line_user_id = '' THEN
    RETURN NEW;
  END IF;

  -- Get property name
  SELECT name INTO v_property_name
  FROM public.properties
  WHERE id = NEW.property_id;

  -- Priority mapping
  CASE COALESCE(NEW.priority, 'medium')
    WHEN 'urgent' THEN v_priority_label := 'เร่งด่วน'; v_priority_emoji := '🔴';
    WHEN 'high'   THEN v_priority_label := 'สูง';      v_priority_emoji := '🟠';
    WHEN 'medium' THEN v_priority_label := 'ปานกลาง';  v_priority_emoji := '🔵';
    WHEN 'low'    THEN v_priority_label := 'ต่ำ';       v_priority_emoji := '⚪';
    ELSE               v_priority_label := NEW.priority; v_priority_emoji := '🔵';
  END CASE;

  -- Build Flex Message
  v_flex := jsonb_build_object(
    'type', 'bubble',
    'header', jsonb_build_object(
      'type', 'box',
      'layout', 'vertical',
      'backgroundColor', '#1DB446',
      'paddingAll', 'lg',
      'contents', jsonb_build_array(
        jsonb_build_object(
          'type', 'text',
          'text', '📢 คุณได้รับมอบหมายงานใหม่!',
          'color', '#FFFFFF',
          'weight', 'bold',
          'size', 'md'
        )
      )
    ),
    'body', jsonb_build_object(
      'type', 'box',
      'layout', 'vertical',
      'spacing', 'md',
      'contents', jsonb_build_array(
        jsonb_build_object(
          'type', 'text',
          'text', '📝 ' || NEW.title,
          'weight', 'bold',
          'size', 'lg',
          'wrap', true
        ),
        jsonb_build_object('type', 'separator'),
        jsonb_build_object(
          'type', 'box',
          'layout', 'vertical',
          'spacing', 'sm',
          'contents', jsonb_build_array(
            jsonb_build_object(
              'type', 'box', 'layout', 'horizontal',
              'contents', jsonb_build_array(
                jsonb_build_object('type', 'text', 'text', '🏠 บ้าน', 'size', 'sm', 'color', '#555555', 'flex', 0),
                jsonb_build_object('type', 'text', 'text', COALESCE(v_property_name, '-'), 'size', 'sm', 'color', '#111111', 'align', 'end', 'weight', 'bold')
              )
            ),
            jsonb_build_object(
              'type', 'box', 'layout', 'horizontal',
              'contents', jsonb_build_array(
                jsonb_build_object('type', 'text', 'text', v_priority_emoji || ' ความสำคัญ', 'size', 'sm', 'color', '#555555', 'flex', 0),
                jsonb_build_object('type', 'text', 'text', v_priority_label, 'size', 'sm', 'color', '#111111', 'align', 'end', 'weight', 'bold')
              )
            )
          )
        )
      )
    ),
    'footer', jsonb_build_object(
      'type', 'box',
      'layout', 'vertical',
      'contents', jsonb_build_array(
        jsonb_build_object(
          'type', 'text',
          'text', 'เข้าดูรายละเอียดที่แอป BaanPool Ops',
          'size', 'xs',
          'color', '#AAAAAA',
          'align', 'center'
        )
      )
    )
  );

  -- Send flex message
  PERFORM public.send_line_flex(
    v_line_user_id,
    '📢 งานใหม่: ' || NEW.title,
    v_flex
  );

  RETURN NEW;
END;
$$;

-- =====================================================
-- 8. Trigger: notify caretaker + managers on status change
-- =====================================================
CREATE OR REPLACE FUNCTION public.trg_notify_work_order_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_property RECORD;
  v_tech_name TEXT;
  v_status_text TEXT;
  v_emoji TEXT;
  v_message TEXT;
  v_recipient RECORD;
BEGIN
  -- Only fire when status actually changes
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- Get property info
  SELECT name, caretaker_id INTO v_property
  FROM public.properties
  WHERE id = NEW.property_id;

  -- Get technician name
  IF NEW.assigned_to IS NOT NULL THEN
    SELECT full_name INTO v_tech_name
    FROM public.users
    WHERE id = NEW.assigned_to;
  END IF;

  -- Status display text
  CASE NEW.status
    WHEN 'open'        THEN v_status_text := 'เปิด';           v_emoji := '🆕';
    WHEN 'in_progress' THEN v_status_text := 'กำลังดำเนินการ'; v_emoji := '🔄';
    WHEN 'completed'   THEN v_status_text := 'เสร็จแล้ว';      v_emoji := '✅';
    WHEN 'cancelled'   THEN v_status_text := 'ยกเลิก';         v_emoji := '❌';
    ELSE                    v_status_text := NEW.status;        v_emoji := '📋';
  END CASE;

  -- Build message (compact: title, property, status only)
  v_message := v_emoji || ' ใบงานอัปเดตสถานะ' || chr(10)
    || '📝 ' || NEW.title || chr(10)
    || '🏠 บ้าน: ' || COALESCE(v_property.name, '-') || chr(10)
    || '📊 สถานะ: ' || v_status_text;

  -- Notify caretaker of this property
  IF v_property.caretaker_id IS NOT NULL THEN
    FOR v_recipient IN
      SELECT line_user_id FROM public.users
      WHERE id = v_property.caretaker_id
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

  RETURN NEW;
END;
$$;

-- =====================================================
-- 9. Create the triggers
-- =====================================================
DROP TRIGGER IF EXISTS trg_work_order_assigned ON public.work_orders;
CREATE TRIGGER trg_work_order_assigned
  AFTER INSERT OR UPDATE OF assigned_to ON public.work_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_work_order_assigned();

DROP TRIGGER IF EXISTS trg_work_order_status ON public.work_orders;
CREATE TRIGGER trg_work_order_status
  AFTER UPDATE OF status ON public.work_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_work_order_status();

-- =====================================================
-- DONE! Now update the token:
--
-- UPDATE app_settings
-- SET value = 'GC8YYECcuqn8Q6JVu8d5Eav/8ol2i9DDOmd8v/0gQlRon6wTq2o/sXJFWkVHuLCGXcRE1dIubU8bYrtzu73ZqpoZnHHzPSs5nJHZNd+vz4LSyJFK6NQIfSi5eNHrz/LpwdWFGWzweAg/AgK3v932QgdB04t89/1O/w1cDnyilFU='
-- WHERE key = 'line_messaging_token';
--
-- =====================================================
