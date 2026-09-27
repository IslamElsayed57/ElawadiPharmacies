-- ==========================================================================
-- صيدليات العوضي (Elawadi Pharmacies) - Supabase Database Schema & RLS Setup
-- Run this complete SQL script in your Supabase SQL Editor:
-- ==========================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================================================
-- 2. STORAGE BUCKETS CONFIGURATION
-- ==========================================================================
-- Ensure 'product-images' bucket exists and is public for catalog display
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Ensure 'prescriptions' bucket exists and set to PRIVATE for medical privacy (5MB limit, images/PDF)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'prescriptions',
    'prescriptions',
    false,
    5242880,
    ARRAY['image/jpeg','image/png','image/webp','image/gif','application/pdf']
)
ON CONFLICT (id) DO UPDATE SET 
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','image/gif','application/pdf'];

-- ==========================================================================
-- 3. BRANCHES TABLE
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_ar TEXT NOT NULL,
    name_en TEXT,
    city TEXT NOT NULL DEFAULT 'الدقهلية',
    address TEXT NOT NULL,
    phone TEXT,
    hours TEXT DEFAULT '24 ساعة يومياً (خدمة التوصيل متاحة)',
    manager TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed initial branches matching the customer website if not present
INSERT INTO public.branches (name_ar, name_en, city, address, phone, manager)
VALUES 
    ('فرع طناح - المنصورة - الدقهلية', 'Tanah Branch - Mansoura - Dakahlia', 'الدقهلية', 'الشارع الرئيسي - بجوار المجمع الطبي، طناح، مركز المنصورة، الدقهلية', '050-2450001', 'د. إسلام السيد'),
    ('فرع كفر طناح - المنصورة - الدقهلية', 'Kafr Tanah Branch - Mansoura - Dakahlia', 'الدقهلية', 'طريق كفر طناح الرئيسي - أمام المسجد الكبير، كفر طناح، المنصورة، الدقهلية', '050-2450002', 'د. أحمد العوضي')
ON CONFLICT DO NOTHING;

-- ==========================================================================
-- 4. PROFILES TABLE (Linked to auth.users)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    mobile TEXT,
    role TEXT NOT NULL CHECK (role IN ('admin', 'pharmacist')),
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================================================
-- 5. CATEGORIES TABLE
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_ar TEXT NOT NULL,
    name_en TEXT,
    slug TEXT UNIQUE NOT NULL,
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed default categories
INSERT INTO public.categories (name_ar, name_en, slug)
VALUES
    ('الأدوية والعلاجات', 'Medicines & Treatments', 'medicines'),
    ('العناية بالبشرة', 'Skincare & Cosmetics', 'skincare'),
    ('العناية بالشعر', 'Haircare', 'haircare'),
    ('الفيتامينات والمكملات', 'Vitamins & Supplements', 'vitamins'),
    ('الأم والطفل', 'Mother & Baby', 'baby'),
    ('الأجهزة والمعدات الطبية', 'Medical Devices', 'devices')
ON CONFLICT (slug) DO NOTHING;

-- ==========================================================================
-- 6. PRODUCTS TABLE
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_ar TEXT NOT NULL,
    name_en TEXT,
    description TEXT,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    old_price NUMERIC(10, 2),
    badge TEXT,
    badge_type TEXT DEFAULT 'official',
    icon TEXT DEFAULT 'fa-pills',
    image_url TEXT,
    in_stock BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================================================
-- 7. CUSTOMERS TABLE (Optional Directory aggregator)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    mobile TEXT UNIQUE NOT NULL,
    address TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================================================
-- 8. EXTEND EXISTING 'orders' TABLE (Preserves all existing data)
-- ==========================================================================
ALTER TABLE public.orders 
    ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS order_type TEXT DEFAULT 'delivery',
    ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC(10, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total NUMERIC(10, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS prescription_path TEXT,
    ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- ==========================================================================
-- 9. ORDER ITEMS TABLE (Preserves Historical Snapshot)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id BIGINT REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name_snapshot TEXT NOT NULL,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================================================
-- 10. ORDER STATUS AUDIT HISTORY TABLE
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id BIGINT REFERENCES public.orders(id) ON DELETE CASCADE,
    old_status TEXT,
    new_status TEXT NOT NULL,
    changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================================================
-- 11. PHARMACY SETTINGS TABLE
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.settings (key, value)
VALUES 
    ('pharmacy_info', '{"name_ar": "صيدليات العوضي", "name_en": "Elawadi Pharmacies", "hotline": "19850", "whatsapp": "01000000000", "email": "care@elawadipharmacies.eg"}'::jsonb),
    ('delivery_rules', '{"default_fee": 25.00, "free_delivery_threshold": 500.00, "estimated_time": "30-45 دقيقة"}'::jsonb),
    ('social_links', '{"facebook": "", "instagram": "", "tiktok": "", "twitter": ""}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ==========================================================================
-- 12. HELPER FUNCTIONS & TRIGGERS
-- ==========================================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin' AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.get_user_branch()
RETURNS UUID AS $$
BEGIN
  RETURN (
    SELECT branch_id FROM public.profiles
    WHERE id = auth.uid() AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- ==========================================================================
-- 13. ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================================================
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- Branches
DROP POLICY IF EXISTS "Public read active branches" ON public.branches;
CREATE POLICY "Public read active branches" ON public.branches FOR SELECT USING (is_active = true OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admin write branches" ON public.branches;
CREATE POLICY "Admin write branches" ON public.branches FOR ALL USING (public.is_admin());

-- Categories
DROP POLICY IF EXISTS "Public read active categories" ON public.categories;
CREATE POLICY "Public read active categories" ON public.categories FOR SELECT USING (is_active = true OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admin write categories" ON public.categories;
CREATE POLICY "Admin write categories" ON public.categories FOR ALL USING (public.is_admin());

-- Products
DROP POLICY IF EXISTS "Public read active products" ON public.products;
CREATE POLICY "Public read active products" ON public.products FOR SELECT USING (is_active = true OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admin write products" ON public.products;
CREATE POLICY "Admin write products" ON public.products FOR ALL USING (public.is_admin());

-- Profiles
DROP POLICY IF EXISTS "User can read own profile or admin reads all" ON public.profiles;
CREATE POLICY "User can read own profile or admin reads all" ON public.profiles FOR SELECT USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "Admin write profiles" ON public.profiles;
CREATE POLICY "Admin write profiles" ON public.profiles FOR ALL USING (public.is_admin());

-- Customers
DROP POLICY IF EXISTS "Authenticated staff read customers" ON public.customers;
CREATE POLICY "Branch-scoped customers read" ON public.customers FOR SELECT
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.orders o
    JOIN public.profiles p ON p.id = auth.uid()
    WHERE o.phone = customers.mobile
      AND p.role = 'pharmacist'
      AND p.branch_id IS NOT NULL
      AND o.branch_id = p.branch_id
  )
);

DROP POLICY IF EXISTS "Staff insert/update customers" ON public.customers;
DROP POLICY IF EXISTS "Staff insert customers" ON public.customers;
DROP POLICY IF EXISTS "Staff update customers" ON public.customers;
DROP POLICY IF EXISTS "Admin delete customers" ON public.customers;

CREATE POLICY "Staff insert customers" ON public.customers FOR INSERT 
WITH CHECK (auth.role() = 'authenticated' OR public.is_admin());

CREATE POLICY "Staff update customers" ON public.customers FOR UPDATE 
USING (auth.role() = 'authenticated' OR public.is_admin())
WITH CHECK (auth.role() = 'authenticated' OR public.is_admin());

CREATE POLICY "Admin delete customers" ON public.customers FOR DELETE 
USING (public.is_admin());

-- Orders
DROP POLICY IF EXISTS "Public insert orders" ON public.orders;
CREATE POLICY "Public insert orders" ON public.orders FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admin full access orders" ON public.orders;
CREATE POLICY "Admin full access orders" ON public.orders FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Pharmacist branch orders read" ON public.orders;
CREATE POLICY "Pharmacist branch orders read" ON public.orders FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'pharmacist' AND is_active = true 
    AND (orders.branch_id IS NULL OR orders.branch_id = profiles.branch_id)
  )
);

DROP POLICY IF EXISTS "Pharmacist branch orders update" ON public.orders;
CREATE POLICY "Pharmacist branch orders update" ON public.orders FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'pharmacist' AND is_active = true 
    AND (orders.branch_id IS NULL OR orders.branch_id = profiles.branch_id)
  )
);

-- Order Items
DROP POLICY IF EXISTS "Staff view order items" ON public.order_items;
CREATE POLICY "Staff view order items" ON public.order_items FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Public insert order items" ON public.order_items;
CREATE POLICY "Public insert order items" ON public.order_items FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admin write order items" ON public.order_items;
CREATE POLICY "Admin write order items" ON public.order_items FOR ALL USING (public.is_admin());

-- Order Status History
DROP POLICY IF EXISTS "Staff view status history" ON public.order_status_history;
CREATE POLICY "Staff view status history" ON public.order_status_history FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Staff insert status history" ON public.order_status_history;
CREATE POLICY "Staff insert status history" ON public.order_status_history FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Settings
DROP POLICY IF EXISTS "Staff read settings" ON public.settings;
CREATE POLICY "Staff read settings" ON public.settings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin write settings" ON public.settings;
CREATE POLICY "Admin write settings" ON public.settings FOR ALL USING (public.is_admin());

-- Storage RLS Policies
DROP POLICY IF EXISTS "Allow public prescription upload" ON storage.objects;
CREATE POLICY "Allow public prescription upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'prescriptions');

DROP POLICY IF EXISTS "Allow authenticated staff view prescriptions" ON storage.objects;
CREATE POLICY "Allow authenticated staff view prescriptions" ON storage.objects FOR SELECT USING (bucket_id = 'prescriptions' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Public read product images" ON storage.objects;
CREATE POLICY "Public read product images" ON storage.objects FOR SELECT USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Admin upload product images" ON storage.objects;
CREATE POLICY "Admin upload product images" ON storage.objects FOR ALL USING (bucket_id = 'product-images' AND auth.role() = 'authenticated');

-- Enable Realtime publication for orders, consultations, and settings
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.settings;

-- ==========================================================================
-- 14. CONSULTATIONS TABLE & POLICIES
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.consultations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    consultation_type TEXT NOT NULL,
    preferred_time TEXT,
    contact_method TEXT NOT NULL DEFAULT 'phone' CHECK (contact_method IN ('phone', 'whatsapp')),
    details TEXT,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'completed', 'no_response')),
    outcome TEXT CHECK (outcome IN ('benefited', 'not_benefited', 'unknown') OR outcome IS NULL),
    outcome_notes TEXT,
    followed_up_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    followed_up_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_consultations_phone ON public.consultations(phone);
CREATE INDEX IF NOT EXISTS idx_consultations_status ON public.consultations(status);
CREATE INDEX IF NOT EXISTS idx_consultations_created_at ON public.consultations(created_at DESC);

ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public insert consultations" ON public.consultations;
CREATE POLICY "Public insert consultations" ON public.consultations FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admin full access consultations" ON public.consultations;
CREATE POLICY "Admin full access consultations" ON public.consultations FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Pharmacist branch consultations read" ON public.consultations;
CREATE POLICY "Pharmacist branch consultations read" ON public.consultations FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'pharmacist' AND is_active = true
        AND (consultations.branch_id IS NULL OR consultations.branch_id = profiles.branch_id)
    )
);

DROP POLICY IF EXISTS "Pharmacist branch consultations update" ON public.consultations;
CREATE POLICY "Pharmacist branch consultations update" ON public.consultations FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'pharmacist' AND is_active = true
        AND (consultations.branch_id IS NULL OR consultations.branch_id = profiles.branch_id)
    )
);

ALTER PUBLICATION supabase_realtime ADD TABLE public.consultations;
