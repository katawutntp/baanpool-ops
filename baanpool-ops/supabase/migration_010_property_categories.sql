-- Property categories table for editable category display names
CREATE TABLE IF NOT EXISTS property_categories (
  prefix TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE property_categories ENABLE ROW LEVEL SECURITY;

-- Everyone can read categories
CREATE POLICY "Anyone can read property categories"
ON property_categories FOR SELECT
USING (true);

-- Only admin/owner/manager can insert/update/delete
CREATE POLICY "Admin can manage property categories"
ON property_categories FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role IN ('admin', 'owner', 'manager')
  )
);

-- Insert default categories
INSERT INTO property_categories (prefix, display_name) VALUES
  ('BS-A', 'BS-A (บ้านเดี่ยว A)'),
  ('BS-HS', 'BS-HS (โฮมสเตย์)'),
  ('BS-M', 'BS-M (บ้านเดี่ยว M)'),
  ('BS-T', 'BS-T (ทาวน์เฮาส์)'),
  ('PT-BT', 'PT-BT (พูลวิลล่า)')
ON CONFLICT (prefix) DO NOTHING;
