-- Elawadi Pharmacies & Clinics consolidated security migrations.
-- Apply sequentially only after both base schema files. This file intentionally
-- preserves the source migration order. Review notes in README.md first.

-- ===== MIGRATION 1 | SOURCE: 01_clinic_tables_require_clinic_profile.sql =====
-- ==========================================================================
-- 01_clinic_tables_require_clinic_profile.sql
-- ==========================================================================
-- يعالج: F1, F2, F3 من نتائج التحقق
-- المشكلة:
--   سياسات clinic_patients و clinic_prescriptions و clinic_appointments
--   تتحقق فقط من وجود صف في clinic_profiles (id = auth.uid())
--   لكن لا تتحقق من أن الحساب نشط (is_active = true).
--   → حساب معطّل (is_active = false) يظل قادراً على قراءة/تعديل البيانات.
--
-- الإصلاح:
--   إضافة AND is_active = true لكل سياسة على الجداول الثلاثة.
--   سياسة p_appointments_insert (الحجز العام) تبقى كما هي (WITH CHECK true).
--   لا نلمس سياسات clinic_categories أو clinic_branches.
--
-- آمن لإعادة التشغيل (DROP IF EXISTS قبل كل CREATE).
-- مستقل عن باقي الملفات — يمكن تشغيله في أي ترتيب.
-- ==========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- clinic_patients
-- ─────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "p_patients_select" ON public.clinic_patients;
CREATE POLICY "p_patients_select"
    ON public.clinic_patients FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_patients_insert" ON public.clinic_patients;
CREATE POLICY "p_patients_insert"
    ON public.clinic_patients FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_patients_update" ON public.clinic_patients;
CREATE POLICY "p_patients_update"
    ON public.clinic_patients FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_patients_delete" ON public.clinic_patients;
CREATE POLICY "p_patients_delete"
    ON public.clinic_patients FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- ─────────────────────────────────────────────────────────────────────────
-- clinic_prescriptions
-- ─────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "p_prescriptions_select" ON public.clinic_prescriptions;
CREATE POLICY "p_prescriptions_select"
    ON public.clinic_prescriptions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_prescriptions_insert" ON public.clinic_prescriptions;
CREATE POLICY "p_prescriptions_insert"
    ON public.clinic_prescriptions FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_prescriptions_update" ON public.clinic_prescriptions;
CREATE POLICY "p_prescriptions_update"
    ON public.clinic_prescriptions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_prescriptions_delete" ON public.clinic_prescriptions;
CREATE POLICY "p_prescriptions_delete"
    ON public.clinic_prescriptions FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- ─────────────────────────────────────────────────────────────────────────
-- clinic_appointments  (INSERT يبقى عام — استمارة الحجز العلنية)
-- ─────────────────────────────────────────────────────────────────────────

-- لا نلمس p_appointments_insert — يبقى WITH CHECK (true)

DROP POLICY IF EXISTS "p_appointments_select" ON public.clinic_appointments;
CREATE POLICY "p_appointments_select"
    ON public.clinic_appointments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_appointments_update" ON public.clinic_appointments;
CREATE POLICY "p_appointments_update"
    ON public.clinic_appointments FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- ==========================================================================
-- ✅ تم — حسابات clinic_profiles المعطّلة لم تعد تملك صلاحية وصول.
-- ==========================================================================


-- ===== MIGRATION 2 | SOURCE: 02_doctor_row_level_scoping.sql =====
-- ==========================================================================
-- 02_doctor_row_level_scoping.sql
-- ==========================================================================
-- يعالج: F4 من نتائج التحقق
-- المشكلة:
--   أي مستخدم في clinic_profiles (بغض النظر عن الدور) يرى كل المرضى
--   والحجوزات والروشتات. الدكتور المفروض يشوف بياناته بس.
--
-- الربط الفعلي (من نتائج الـ audit):
--   clinic_profiles.doctor_id  →  doctors.id
--   clinic_patients.doctor_id  →  doctors.id
--   clinic_appointments.doctor_id  →  doctors.id
--   clinic_prescriptions.doctor_id  →  doctors.id
--
-- الإصلاح:
--   إضافة سياسات RESTRICTIVE (لا تُستبدل الموجودة) بحيث:
--     • غير الدكتور (admin/staff): الـ NOT EXISTS يمررهم بدون قيود
--     • الدكتور: لازم doctor_id في الصف = clinic_profiles.doctor_id بتاعه
--
-- ⚠️  تنبيه أمني مهم:
--   الـ RESTRICTIVE policy بتتطبق بـ AND فوق الـ PERMISSIVE policies.
--   لو كتبنا الشرط بدون NOT EXISTS للـ non-doctors، الأدمن والموظفين
--   هيتحظروا هما كمان! عشان كده كل شرط فيه:
--     NOT EXISTS (... clinic_role = 'doctor' ...)  -- bypass لغير الدكاترة
--     OR doctor_id = (... clinic_profiles.doctor_id ...)  -- قيد على الدكاترة
--
-- آمن لإعادة التشغيل. مستقل عن باقي الملفات.
-- ==========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- clinic_patients — SELECT + UPDATE فقط (كما طُلب)
-- ─────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "doctor_scope_patients_select" ON public.clinic_patients;
CREATE POLICY "doctor_scope_patients_select"
    ON public.clinic_patients
    AS RESTRICTIVE
    FOR SELECT
    USING (
        -- ✅ غير الدكتور (admin/staff): يعدي بدون قيود
        NOT EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid()
              AND clinic_role = 'doctor'
              AND is_active = true
        )
        OR
        -- ✅ الدكتور: يشوف مرضاه بس
        clinic_patients.doctor_id = (
            SELECT cp.doctor_id
            FROM public.clinic_profiles cp
            WHERE cp.id = auth.uid()
              AND cp.clinic_role = 'doctor'
              AND cp.is_active = true
        )
    );

DROP POLICY IF EXISTS "doctor_scope_patients_update" ON public.clinic_patients;
CREATE POLICY "doctor_scope_patients_update"
    ON public.clinic_patients
    AS RESTRICTIVE
    FOR UPDATE
    USING (
        NOT EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid()
              AND clinic_role = 'doctor'
              AND is_active = true
        )
        OR
        clinic_patients.doctor_id = (
            SELECT cp.doctor_id
            FROM public.clinic_profiles cp
            WHERE cp.id = auth.uid()
              AND cp.clinic_role = 'doctor'
              AND cp.is_active = true
        )
    );

-- ─────────────────────────────────────────────────────────────────────────
-- clinic_appointments — SELECT + UPDATE فقط (INSERT عام للحجز العلني)
-- ─────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "doctor_scope_appointments_select" ON public.clinic_appointments;
CREATE POLICY "doctor_scope_appointments_select"
    ON public.clinic_appointments
    AS RESTRICTIVE
    FOR SELECT
    USING (
        -- غير الدكتور: يعدي
        NOT EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid()
              AND clinic_role = 'doctor'
              AND is_active = true
        )
        OR
        -- الدكتور: حجوزاته بس
        clinic_appointments.doctor_id = (
            SELECT cp.doctor_id
            FROM public.clinic_profiles cp
            WHERE cp.id = auth.uid()
              AND cp.clinic_role = 'doctor'
              AND cp.is_active = true
        )
    );

DROP POLICY IF EXISTS "doctor_scope_appointments_update" ON public.clinic_appointments;
CREATE POLICY "doctor_scope_appointments_update"
    ON public.clinic_appointments
    AS RESTRICTIVE
    FOR UPDATE
    USING (
        NOT EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid()
              AND clinic_role = 'doctor'
              AND is_active = true
        )
        OR
        clinic_appointments.doctor_id = (
            SELECT cp.doctor_id
            FROM public.clinic_profiles cp
            WHERE cp.id = auth.uid()
              AND cp.clinic_role = 'doctor'
              AND cp.is_active = true
        )
    );

-- ─────────────────────────────────────────────────────────────────────────
-- clinic_prescriptions — SELECT + UPDATE فقط
-- ─────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "doctor_scope_prescriptions_select" ON public.clinic_prescriptions;
CREATE POLICY "doctor_scope_prescriptions_select"
    ON public.clinic_prescriptions
    AS RESTRICTIVE
    FOR SELECT
    USING (
        NOT EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid()
              AND clinic_role = 'doctor'
              AND is_active = true
        )
        OR
        clinic_prescriptions.doctor_id = (
            SELECT cp.doctor_id
            FROM public.clinic_profiles cp
            WHERE cp.id = auth.uid()
              AND cp.clinic_role = 'doctor'
              AND cp.is_active = true
        )
    );

DROP POLICY IF EXISTS "doctor_scope_prescriptions_update" ON public.clinic_prescriptions;
CREATE POLICY "doctor_scope_prescriptions_update"
    ON public.clinic_prescriptions
    AS RESTRICTIVE
    FOR UPDATE
    USING (
        NOT EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid()
              AND clinic_role = 'doctor'
              AND is_active = true
        )
        OR
        clinic_prescriptions.doctor_id = (
            SELECT cp.doctor_id
            FROM public.clinic_profiles cp
            WHERE cp.id = auth.uid()
              AND cp.clinic_role = 'doctor'
              AND cp.is_active = true
        )
    );

-- ==========================================================================
-- ✅ تم — الدكتور يشوف/يعدّل بياناته بس. الأدمن والموظف بدون قيود.
--
-- ملاحظة: لو clinic_profiles.doctor_id فاضي (NULL) لحساب دكتور،
--   المقارنة هترجع NULL (مش true)، وبالتالي الدكتور مش هيشوف أي بيانات.
--   ده سلوك آمن — لو الدكتور مش مربوط بصف في doctors، لا يصح يشوف مرضى.
-- ==========================================================================


-- ===== MIGRATION 3 | SOURCE: 03_order_totals_server_verified.sql =====
-- ==========================================================================
-- 03_order_totals_server_verified.sql
-- ==========================================================================
-- يعالج: F5 من نتائج التحقق
-- المشكلة:
--   عمود total في جدول orders يُقبل كما يرسله العميل — يمكن تزويره.
--   لا يوجد أي trigger على orders حالياً (الـ audit أكّد: triggers = null).
--
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠️  توضيح مهم عن حدود هذا الإصلاح:
--
--   المشكلة الأصلية: subtotal نفسه بييجي من العميل ومفيش تحقق سيرفري منه.
--   التحقق الكامل يتطلب حساب subtotal من order_items (كمية × سعر الوحدة)
--   لكن حالياً مش كل الأوردرات بتستخدم order_items (بعضها subtotal مباشر).
--
--   ما يفعله هذا الـ trigger:
--   ┌─────────────────────────────────────────────────────────────────────┐
--   │  1. لو فيه order_items مربوطة بالأوردر:                          │
--   │     → subtotal يتحسب سيرفرياً = SUM(order_items.total_price)      │
--   │     → total = subtotal المحسوب + delivery_fee                     │
--   │     → القيمة اللي بعتها العميل لـ subtotal و total بتتكتب فوقها  │
--   │                                                                   │
--   │  2. لو مفيش order_items (الحالة الحالية لمعظم الأوردرات):         │
--   │     → subtotal يبقى زي ما بعته العميل (بدون تغيير)               │
--   │     → total يتحسب = subtotal + delivery_fee                       │
--   │     → ده بيمنع التلاعب في total بس، مش في subtotal               │
--   │                                                                   │
--   │  الخلاصة: الـ trigger بيضمن إن total دايماً صح حسابياً.          │
--   │  لكن subtotal بدون order_items لسه معتمد على العميل.              │
--   │  لو عايز تحقق كامل، لازم كل أوردر يبقى ليه order_items.         │
--   └─────────────────────────────────────────────────────────────────────┘
--
-- القرار: OVERWRITE (يكتب فوق القيمة بدل ما يرمي error)
--   السبب: أأمن — الكود الحالي مش هيتكسر، والقيمة الصح هتتسجل دايماً.
--
-- آمن لإعادة التشغيل. مستقل عن باقي الملفات.
-- ==========================================================================

-- 1) الدالة
CREATE OR REPLACE FUNCTION public.recalculate_order_total()
RETURNS TRIGGER AS $$
DECLARE
    items_total NUMERIC(10, 2);
    items_count INT;
BEGIN
    -- ─────────────────────────────────────────────────────────────────
    -- على UPDATE: لو فيه order_items، احسب subtotal منهم (أدق من العميل)
    -- على INSERT: NEW.id موجود (GENERATED ALWAYS AS IDENTITY) لكن
    --   order_items غالباً لسه مش موجودين، فهنستخدم subtotal المُرسل.
    -- ─────────────────────────────────────────────────────────────────
    IF TG_OP = 'UPDATE' AND NEW.id IS NOT NULL THEN
        SELECT COALESCE(SUM(total_price), 0), COUNT(*)
        INTO items_total, items_count
        FROM public.order_items
        WHERE order_id = NEW.id;

        IF items_count > 0 THEN
            -- order_items موجودة → subtotal يتحسب سيرفرياً
            NEW.subtotal := items_total;
        END IF;
    END IF;

    -- ─────────────────────────────────────────────────────────────────
    -- دايماً: total = subtotal + delivery_fee (سيرفري، مش قابل للتزوير)
    -- ─────────────────────────────────────────────────────────────────
    NEW.total := COALESCE(NEW.subtotal, 0) + COALESCE(NEW.delivery_fee, 0);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 2) الـ trigger
DROP TRIGGER IF EXISTS trg_recalculate_order_total ON public.orders;
CREATE TRIGGER trg_recalculate_order_total
    BEFORE INSERT OR UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.recalculate_order_total();

-- ==========================================================================
-- ✅ تم — total يتحسب سيرفرياً دايماً.
--    لو order_items موجودة: subtotal كمان يتحسب سيرفرياً.
--    لو مفيش order_items: subtotal يبقى زي ما بعته العميل.
-- ==========================================================================


-- ===== MIGRATION 4 | SOURCE: 04_order_items_insert_restricted.sql =====
-- ==========================================================================
-- 04_order_items_insert_restricted.sql
-- ==========================================================================
-- يعالج: F6 من نتائج التحقق
-- المشكلة:
--   سياسة "Public insert order items" حالياً: WITH CHECK (true)
--   → أي شخص (حتى anonymous) يقدر يضيف items لأي أوردر في النظام.
--
-- الإصلاح:
--   1. auth.role() = 'authenticated' (لازم يكون مسجل دخول)
--   2. الأوردر (order_id) لازم يكون مرئي للمستخدم حسب نفس منطق
--      الفرع المستخدم في سياسة SELECT على orders:
--      - is_admin() → كل الأوردرات
--      - pharmacist → أوردرات فرعه أو الأوردرات بدون فرع
--
-- آمن لإعادة التشغيل. مستقل عن باقي الملفات.
-- ==========================================================================

DROP POLICY IF EXISTS "Public insert order items" ON public.order_items;
CREATE POLICY "Staff insert order items"
    ON public.order_items
    FOR INSERT
    WITH CHECK (
        auth.role() = 'authenticated'
        AND EXISTS (
            SELECT 1 FROM public.orders
            WHERE orders.id = order_items.order_id
              AND (
                  -- أدمن: كل الأوردرات
                  public.is_admin()
                  OR
                  -- صيدلي: أوردرات فرعه أو بدون فرع
                  EXISTS (
                      SELECT 1 FROM public.profiles
                      WHERE profiles.id = auth.uid()
                        AND profiles.role = 'pharmacist'
                        AND profiles.is_active = true
                        AND (orders.branch_id IS NULL OR orders.branch_id = profiles.branch_id)
                  )
              )
        )
    );

-- ==========================================================================
-- ✅ تم — order_items INSERT الآن مقيّد بنفس منطق الفرع المستخدم في orders.
-- ==========================================================================


-- ===== MIGRATION 5 | SOURCE: 05_order_status_history_branch_scoped.sql =====
-- ==========================================================================
-- 05_order_status_history_branch_scoped.sql
-- ==========================================================================
-- يعالج: F7 من نتائج التحقق
-- المشكلة:
--   سياسة "Staff insert status history" حالياً:
--     WITH CHECK (auth.role() = 'authenticated')
--   → أي مستخدم مسجل دخول يقدر يسجل تاريخ حالة لأي أوردر
--     (حتى أوردرات فروع تانية).
--
-- الإصلاح:
--   نفس شرط الفرع المستخدم في سياسة UPDATE على orders:
--   - أدمن: بدون قيود
--   - صيدلي: فقط أوردرات فرعه أو الأوردرات بدون فرع
--
-- آمن لإعادة التشغيل. مستقل عن باقي الملفات.
-- ==========================================================================

DROP POLICY IF EXISTS "Staff insert status history" ON public.order_status_history;
CREATE POLICY "Staff insert status history"
    ON public.order_status_history
    FOR INSERT
    WITH CHECK (
        -- أدمن: يقدر يسجل لأي أوردر
        public.is_admin()
        OR
        -- صيدلي: بس لأوردرات فرعه أو أوردرات بدون فرع
        EXISTS (
            SELECT 1
            FROM public.orders o
            JOIN public.profiles p ON p.id = auth.uid()
            WHERE o.id = order_status_history.order_id
              AND p.role = 'pharmacist'
              AND p.is_active = true
              AND (o.branch_id IS NULL OR o.branch_id = p.branch_id)
        )
    );

-- سياسة SELECT تبقى كما هي (auth.role() = 'authenticated')
-- لأن الطلب لم يشمل تعديلها.

-- ==========================================================================
-- ✅ تم — تسجيل تاريخ الحالة الآن مقيّد بنفس منطق الفرع المستخدم في
--    orders UPDATE.
-- ==========================================================================


-- ===== MIGRATION 6 | SOURCE: 06_prescriptions_storage_branch_scoped.sql =====
-- ==========================================================================
-- 06_prescriptions_storage_branch_scoped.sql
-- ==========================================================================
-- يعالج: F8 من نتائج التحقق
-- المشكلة:
--   سياسة "Allow authenticated staff view prescriptions" حالياً:
--     USING (bucket_id = 'prescriptions' AND auth.role() = 'authenticated')
--   → أي مستخدم مسجل دخول يقدر يشوف كل ملفات الروشتات
--     بما فيها روشتات فروع تانية.
--
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠️  قيد تقني لا يمكن حله في SQL وحده:
--
--   لتطبيق branch-scoping على ملفات الـ storage، لازم مسار الملف
--   (object name/path) يحتوي على معرّف يمكن ربطه بالفرع.
--
--   المسار الحالي للملفات:
--     prescriptions/{timestamp}_{random}.{ext}
--   → لا يوجد order_id أو branch_id في المسار.
--
--   عشان نقدر نقفل بالفرع في المستقبل، لازم صيغة الرفع تتغير لحاجة زي:
--     prescriptions/{branch_id}/{order_id}/{timestamp}.{ext}
--   أو:
--     prescriptions/{order_id}_{timestamp}.{ext}
--   وبعدين الـ policy تستخرج الـ order_id من المسار وتتحقق من الفرع.
--
--   القرار الحالي:
--   → نخليها "authenticated staff only" مع تقوية إضافية:
--      لازم يكون عنده صف نشط في profiles (مش بس authenticated).
--   → ده أأمن من الوضع الحالي (أي authenticated يشوف) لكن مش branch-scoped.
--
--   لو قررت تغير صيغة الرفع لاحقاً، قولي وأكتبلك الـ policy المحدّثة.
-- ─────────────────────────────────────────────────────────────────────────
--
-- آمن لإعادة التشغيل. مستقل عن باقي الملفات.
-- ==========================================================================

DROP POLICY IF EXISTS "Allow authenticated staff view prescriptions" ON storage.objects;
CREATE POLICY "Allow authenticated staff view prescriptions"
    ON storage.objects
    FOR SELECT
    USING (
        bucket_id = 'prescriptions'
        AND (
            -- أدمن: يشوف كل الروشتات
            public.is_admin()
            OR
            -- صيدلي نشط: يشوف كل الروشتات (بدون branch scoping — انظر القيد أعلاه)
            EXISTS (
                SELECT 1 FROM public.profiles
                WHERE id = auth.uid()
                  AND role = 'pharmacist'
                  AND is_active = true
            )
        )
    );

-- ==========================================================================
-- ✅ تم — الوصول الآن مقيّد بـ profiles نشطة (مش مجرد authenticated).
--    Branch scoping يحتاج تغيير صيغة مسار الرفع أولاً (انظر التعليق أعلاه).
-- ==========================================================================


-- ===== MIGRATION 7 | SOURCE: 07_product_images_admin_only.sql =====
-- ==========================================================================
-- 07_product_images_admin_only.sql
-- ==========================================================================
-- يعالج: F9 من نتائج التحقق
-- المشكلة:
--   سياسة "Admin upload product images" حالياً:
--     USING (bucket_id = 'product-images' AND auth.role() = 'authenticated')
--   → أي مستخدم مسجل دخول (صيدلي، موظف عيادة، أو حتى أي authenticated user)
--     يقدر يرفع/يعدّل/يمسح صور المنتجات. الاسم يقول "Admin" لكن الشرط
--     لا يتحقق فعلاً من صلاحية الأدمن.
--
-- الإصلاح:
--   استبدال auth.role() = 'authenticated' بـ is_admin()
--   (الدالة موجودة ومُعرّفة كـ SECURITY DEFINER في schema.sql).
--
-- آمن لإعادة التشغيل. مستقل عن باقي الملفات.
-- ==========================================================================

DROP POLICY IF EXISTS "Admin upload product images" ON storage.objects;
CREATE POLICY "Admin upload product images"
    ON storage.objects
    FOR ALL
    USING (
        bucket_id = 'product-images'
        AND public.is_admin()
    )
    WITH CHECK (
        bucket_id = 'product-images'
        AND public.is_admin()
    );

-- سياسة القراءة العامة "Public read product images" لا تتغير
-- (المنتجات صورها عامة للعرض على الموقع).

-- ==========================================================================
-- ✅ تم — رفع/تعديل/مسح صور المنتجات الآن مقيّد بالأدمن فقط.
-- ==========================================================================


-- ===== MIGRATION 8 | SOURCE: 08_rate_limiting.sql =====
-- ==========================================================================
-- 08_rate_limiting.sql
-- ==========================================================================
-- يعالج: F10 من نتائج التحقق
-- المشكلة:
--   جداول orders و consultations و clinic_appointments تقبل INSERT عام
--   (WITH CHECK true) بدون أي حد لعدد الطلبات — يمكن إغراق النظام.
--
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠️  المعرّف المستخدم (Identifier):
--
--   في Supabase، الـ INSERT العام (anonymous) يمر عبر PostgREST.
--   لا يوجد وسيلة موثوقة لمعرفة IP العميل من داخل Postgres:
--   - current_setting('request.headers', true) قد تكون متاحة لكن
--     x-forwarded-for غير مضمون (proxy chains) وغير موثوق.
--   - inet_client_addr() ترجع IP الـ PostgREST server، مش العميل.
--
--   القرار: استخدام رقم التليفون كمعرّف.
--   السبب: كل الاستمارات الثلاث (أوردر، استشارة، حجز عيادة) تجمع
--          رقم التليفون كحقل إلزامي. ده أفضل معرّف متاح.
--
--   أسماء أعمدة التليفون (من نتائج الـ audit):
--     • orders          → phone
--     • consultations   → phone
--     • clinic_appointments → patient_phone
--
--   ⚠️  حد معروف لهذا الحل: أي شخص يقدر يتخطاه لو غيّر رقم التليفون
--   في كل طلب (أرقام وهمية متعددة). هذا حد طبيعي لأي rate-limit
--   بدون IP أو CAPTCHA، وخارج نطاق هذا الإصلاح. الحل الكامل لاحقاً
--   لو احتجته: خدمة خارجية زي Cloudflare Turnstile على النماذج العامة.
-- ─────────────────────────────────────────────────────────────────────────
--
-- آمن لإعادة التشغيل. مستقل عن باقي الملفات.
-- ==========================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) جدول السجل
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.rate_limit_log (
    id       BIGSERIAL PRIMARY KEY,
    bucket   TEXT        NOT NULL,
    identifier TEXT      NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- فهرس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_rate_limit_lookup
    ON public.rate_limit_log (bucket, identifier, created_at);

-- تفعيل RLS بدون أي policy → يمنع الوصول المباشر عبر API
ALTER TABLE public.rate_limit_log ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) دالة الفحص
-- ═══════════════════════════════════════════════════════════════════════════
-- ملاحظة أمنية: SECURITY DEFINER بدون search_path ثابت يفتح احتمال
-- search_path hijacking (لو حد قدر يتحكم في الـ search_path بتاع الجلسة).
-- إضافة SET search_path = public, pg_temp تمنع الاحتمال ده تمامًا.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_bucket         TEXT,
    p_identifier     TEXT,
    p_max_count      INT,
    p_window_seconds INT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER  -- تشتغل بصلاحيات المالك → تتجاوز RLS على rate_limit_log
SET search_path = public, pg_temp
AS $$
DECLARE
    current_count INT;
BEGIN
    -- عد الطلبات في النافذة الزمنية
    SELECT COUNT(*)
    INTO current_count
    FROM public.rate_limit_log
    WHERE bucket     = p_bucket
      AND identifier = p_identifier
      AND created_at > now() - make_interval(secs => p_window_seconds);

    -- لو وصل الحد → ارفض
    IF current_count >= p_max_count THEN
        RETURN false;
    END IF;

    -- تحت الحد → سجّل الطلب واسمح
    INSERT INTO public.rate_limit_log (bucket, identifier)
    VALUES (p_bucket, p_identifier);

    RETURN true;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- حماية الدالة من الاستدعاء الخارجي عبر Supabase RPC:
-- دالة check_rate_limit داخلية تُستدعى فقط عبر الـ Triggers.
-- سحب EXECUTE من PUBLIC و anon و authenticated يمنع أي مستخدم أو زائر من استدعائها مباشرة.
-- ═══════════════════════════════════════════════════════════════════════════
REVOKE EXECUTE ON FUNCTION public.check_rate_limit(text, text, int, int) FROM PUBLIC, anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Trigger functions — واحدة لكل جدول (اسم العمود مختلف)
-- ملاحظة أمنية: معرّفة SECURITY DEFINER بصلاحيات المالك لكي تتمكن من
-- استدعاء check_rate_limit المحمية بدون إعطاء صلاحيات للـ anon مباشرة.
-- ═══════════════════════════════════════════════════════════════════════════

-- 3a) orders  →  عمود التليفون: phone
CREATE OR REPLACE FUNCTION public.rate_limit_orders()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.check_rate_limit(
        'orders',
        COALESCE(NEW.phone, 'anonymous'),
        10,   -- أقصى عدد
        600   -- نافذة: 10 دقائق (600 ثانية)
    ) THEN
        RAISE EXCEPTION 'تم تجاوز الحد المسموح لتقديم الطلبات. يرجى المحاولة لاحقاً.'
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$;

-- 3b) consultations  →  عمود التليفون: phone
CREATE OR REPLACE FUNCTION public.rate_limit_consultations()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.check_rate_limit(
        'consultations',
        COALESCE(NEW.phone, 'anonymous'),
        10,
        600
    ) THEN
        RAISE EXCEPTION 'تم تجاوز الحد المسموح لطلبات الاستشارة. يرجى المحاولة لاحقاً.'
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$;

-- 3c) clinic_appointments  →  عمود التليفون: patient_phone
CREATE OR REPLACE FUNCTION public.rate_limit_appointments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.check_rate_limit(
        'clinic_appointments',
        COALESCE(NEW.patient_phone, 'anonymous'),
        10,
        600
    ) THEN
        RAISE EXCEPTION 'تم تجاوز الحد المسموح لطلبات الحجز. يرجى المحاولة لاحقاً.'
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) ربط الـ triggers
-- ═══════════════════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS trg_rate_limit_orders ON public.orders;
CREATE TRIGGER trg_rate_limit_orders
    BEFORE INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.rate_limit_orders();

DROP TRIGGER IF EXISTS trg_rate_limit_consultations ON public.consultations;
CREATE TRIGGER trg_rate_limit_consultations
    BEFORE INSERT ON public.consultations
    FOR EACH ROW
    EXECUTE FUNCTION public.rate_limit_consultations();

DROP TRIGGER IF EXISTS trg_rate_limit_appointments ON public.clinic_appointments;
CREATE TRIGGER trg_rate_limit_appointments
    BEFORE INSERT ON public.clinic_appointments
    FOR EACH ROW
    EXECUTE FUNCTION public.rate_limit_appointments();

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) تنظيف دوري (ملاحظة — ليس cron job تلقائي)
-- ═══════════════════════════════════════════════════════════════════════════
-- يُنصح بتشغيل الاستعلام التالي دورياً (يومياً مثلاً) لحذف السجلات القديمة:
--
--   DELETE FROM public.rate_limit_log
--   WHERE created_at < now() - interval '24 hours';
--
-- يمكن تنفيذه عبر:
--   • Supabase Edge Function مجدولة (cron)
--   • pg_cron extension لو متاحة في مشروعك
--   • أو يدوياً من SQL Editor كل فترة
--
-- بدون تنظيف، الجدول هيكبر مع الوقت لكن الفهرس يخلي الأداء مقبول.

-- ==========================================================================
-- ✅ تم — Rate limiting مفعّل ومحصّن:
--    • 10 طلبات كحد أقصى لكل رقم تليفون كل 10 دقائق
--    • على: orders, consultations, clinic_appointments
--    • المعرّف: رقم التليفون (phone / patient_phone)
--    • check_rate_limit() محمية بـ SET search_path = public, pg_temp
--    • سحب EXECUTE من check_rate_limit لمنع استغلالها كـ RPC
--    • دوال الـ triggers معرّفة كـ SECURITY DEFINER
-- ==========================================================================


-- ===== MIGRATION 9 | SOURCE: 10_privilege_escalation_and_functions_hardening.sql =====
-- ==========================================================================
-- 10_privilege_escalation_and_functions_hardening.sql
-- ==========================================================================
-- يعالج:
--   1) إغلاق ثغرة استدعاء check_rate_limit مباشرة كـ RPC من أي زائر.
--   2) تحصين دوال is_admin() و get_user_branch() ضد search_path hijacking.
--   3) إغلاق ثغرة رفع الصلاحيات (Privilege Escalation) وتغيير doctor_id في clinic_profiles.
--
-- آمن لإعادة التشغيل تماماً (Idempotent).
-- ==========================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) تحصين Rate Limiting ومنع استدعاء check_rate_limit عبر Supabase RPC
-- ═══════════════════════════════════════════════════════════════════════════

-- جعل دوال الـ Triggers تعمل كـ SECURITY DEFINER بصلاحيات المالك
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rate_limit_orders') THEN
        ALTER FUNCTION public.rate_limit_orders() SECURITY DEFINER SET search_path = public, pg_temp;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rate_limit_consultations') THEN
        ALTER FUNCTION public.rate_limit_consultations() SECURITY DEFINER SET search_path = public, pg_temp;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rate_limit_appointments') THEN
        ALTER FUNCTION public.rate_limit_appointments() SECURITY DEFINER SET search_path = public, pg_temp;
    END IF;

    -- سحب صلاحية التنفيذ المباشر من الزوار والعملاء لمنع استدعائها عبر Supabase RPC
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'check_rate_limit'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.check_rate_limit(text, text, int, int) FROM PUBLIC, anon, authenticated;
    END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 2) تحصين دوال الصلاحيات في schema.sql بـ search_path ثابت
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'is_admin'
    ) THEN
        ALTER FUNCTION public.is_admin() SECURITY DEFINER SET search_path = public, pg_temp;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'get_user_branch'
    ) THEN
        ALTER FUNCTION public.get_user_branch() SECURITY DEFINER SET search_path = public, pg_temp;
    END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 3) إغلاق ثغرة رفع الصلاحيات على clinic_profiles (Privilege Escalation)
-- ═══════════════════════════════════════════════════════════════════════════
-- المشكلة:
--   كانت سياسة p_profiles_update تسمح بتعديل الصف إذا كان id = auth.uid()
--   بدون WITH CHECK يمنع تغيير clinic_role أو doctor_id.
--   المهاجم كان يستطيع إرسال:
--     .update({ clinic_role: 'clinic_admin' }) أو
--     .update({ doctor_id: 'another-doctor-uuid' })
--   وبالتالي يتحول إلى أدمن أو يخرق عزل الأطباء (02_doctor_row_level_scoping.sql).
--
-- الحل بمستويين (Defense in Depth):
--   أ) تصحيح سياسة RLS: حصر التعديل على الأدمن النشط فقط.
--   ب) Trigger حماية مشدد: يفحص القيم القديمة والجديدة ويمنع أي مستخدم
--      غير clinic_admin من تعديل clinic_role أو doctor_id أو is_active
--      حتى لو عُدلت سياسة الـ RLS لاحقاً.
-- ═══════════════════════════════════════════════════════════════════════════

-- أ) إعادة بناء سياسات clinic_profiles
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public' AND tablename = 'clinic_profiles'
    ) THEN
        DROP POLICY IF EXISTS "p_profiles_update" ON public.clinic_profiles;
        CREATE POLICY "p_profiles_update"
            ON public.clinic_profiles FOR UPDATE
            USING (
                EXISTS (
                    SELECT 1 FROM public.clinic_profiles 
                    WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.clinic_profiles 
                    WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
                )
            );

        DROP POLICY IF EXISTS "p_profiles_insert" ON public.clinic_profiles;
        CREATE POLICY "p_profiles_insert"
            ON public.clinic_profiles FOR INSERT
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.clinic_profiles 
                    WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
                )
            );
    END IF;
END $$;

-- ب) دالة و Trigger الحماية على clinic_profiles
CREATE OR REPLACE FUNCTION public.protect_clinic_profiles_sensitive_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- إذا لم يكن المستخدم القائم بالتعديل أدمن عيادات نشط
    IF NOT EXISTS (
        SELECT 1 FROM public.clinic_profiles
        WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
    ) THEN
        -- منع تغيير الدور clinic_role
        IF NEW.clinic_role IS DISTINCT FROM OLD.clinic_role THEN
            RAISE EXCEPTION 'غير مصرح لك بتغيير الصلاحية (clinic_role)' USING ERRCODE = '42501';
        END IF;

        -- منع تغيير ربط الطبيب doctor_id
        IF NEW.doctor_id IS DISTINCT FROM OLD.doctor_id THEN
            RAISE EXCEPTION 'غير مصرح لك بتغيير معرّف الطبيب (doctor_id)' USING ERRCODE = '42501';
        END IF;

        -- منع تغيير حالة الحساب is_active
        IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
            RAISE EXCEPTION 'غير مصرح لك بتغيير حالة الحساب (is_active)' USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public' AND tablename = 'clinic_profiles'
    ) THEN
        DROP TRIGGER IF EXISTS trg_protect_clinic_profiles ON public.clinic_profiles;
        CREATE TRIGGER trg_protect_clinic_profiles
            BEFORE UPDATE ON public.clinic_profiles
            FOR EACH ROW
            EXECUTE FUNCTION public.protect_clinic_profiles_sensitive_columns();
    END IF;
END $$;


-- ===== MIGRATION 10 | SOURCE: 11_delete_permissions_and_storage_hardening.sql =====
-- ==========================================================================
-- 11_delete_permissions_and_storage_hardening.sql
-- ==========================================================================
-- يعالج:
--   1) حصر صلاحية الحذف (DELETE) على الأدمن فقط في جداول:
--      - customers (منع الصيادلة أو الموظفين من حذف العملاء)
--      - clinic_patients (منع أي موظف أو دكتور عادي من حذف سجلات المرضى)
--      - clinic_prescriptions (حماية الروشتات الطبية من الحذف)
--   2) تحصين Storage الخاص بالعيادات (clinic-uploads):
--      - الرفع يتطلب حساب نشط وموثق في clinic_profiles.
--      - الحذف مقصور حصرياً على clinic_admin.
--   3) تحصين دالة recalculate_order_total بـ SECURITY DEFINER و search_path ثابت.
--
-- آمن لإعادة التشغيل تماماً (Idempotent).
-- ==========================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) حصر صلاحية حذف العملاء على الأدمن فقط (customers)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public' AND tablename = 'customers'
    ) THEN
        -- حذف السياسة القديمة التي كانت تمنح FOR ALL
        DROP POLICY IF EXISTS "Staff insert/update customers" ON public.customers;
        DROP POLICY IF EXISTS "Staff insert customers" ON public.customers;
        DROP POLICY IF EXISTS "Staff update customers" ON public.customers;
        DROP POLICY IF EXISTS "Admin delete customers" ON public.customers;

        -- الإضافة: مسموحة للموظفين والأدمن
        CREATE POLICY "Staff insert customers" ON public.customers
            FOR INSERT 
            WITH CHECK (auth.role() = 'authenticated' OR public.is_admin());

        -- التعديل: مسموح للموظفين والأدمن
        CREATE POLICY "Staff update customers" ON public.customers
            FOR UPDATE 
            USING (auth.role() = 'authenticated' OR public.is_admin())
            WITH CHECK (auth.role() = 'authenticated' OR public.is_admin());

        -- الحذف: مقصور على الأدمن فقط!
        CREATE POLICY "Admin delete customers" ON public.customers
            FOR DELETE 
            USING (public.is_admin());
    END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 2) حصر حذف المرضى والروشتات على clinic_admin فقط
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
    -- أ) جدول clinic_patients
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public' AND tablename = 'clinic_patients'
    ) THEN
        DROP POLICY IF EXISTS "p_patients_delete" ON public.clinic_patients;
        CREATE POLICY "p_patients_delete"
            ON public.clinic_patients FOR DELETE
            USING (
                EXISTS (
                    SELECT 1 FROM public.clinic_profiles 
                    WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
                )
            );
    END IF;

    -- ب) جدول clinic_prescriptions
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public' AND tablename = 'clinic_prescriptions'
    ) THEN
        DROP POLICY IF EXISTS "p_prescriptions_delete" ON public.clinic_prescriptions;
        CREATE POLICY "p_prescriptions_delete"
            ON public.clinic_prescriptions FOR DELETE
            USING (
                EXISTS (
                    SELECT 1 FROM public.clinic_profiles 
                    WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
                )
            );
    END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 3) تحصين سياسات Storage العيادات (clinic-uploads)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
    -- الرفع: يتطلب حساب نشط ومسجل في clinic_profiles
    DROP POLICY IF EXISTS "Clinic uploads write" ON storage.objects;
    CREATE POLICY "Clinic uploads write"
        ON storage.objects FOR INSERT
        WITH CHECK (
            bucket_id = 'clinic-uploads'
            AND EXISTS (
                SELECT 1 FROM public.clinic_profiles
                WHERE id = auth.uid() AND is_active = true
            )
        );

    -- الحذف: مقصور على أدمن العيادات فقط
    DROP POLICY IF EXISTS "Clinic uploads delete" ON storage.objects;
    CREATE POLICY "Clinic uploads delete"
        ON storage.objects FOR DELETE
        USING (
            bucket_id = 'clinic-uploads'
            AND EXISTS (
                SELECT 1 FROM public.clinic_profiles
                WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
            )
        );
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 4) تحصين دالة recalculate_order_total بـ search_path ثابت
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'recalculate_order_total'
    ) THEN
        ALTER FUNCTION public.recalculate_order_total() SECURITY DEFINER SET search_path = public, pg_temp;
    END IF;
END $$;


-- ===== MIGRATION 11 | SOURCE: 12_level1_fixes.sql =====
-- ==========================================================================
-- 12_level1_fixes.sql
-- ==========================================================================
-- يعالج بنود 2 و4 و5 من المستوى الأول:
--   2) حذف السياسات المكررة (رفع الروشتات + إدخال الطلبات)
--   4) قراءة order_items و order_status_history بنفس منطق الفرع بتاع orders
--   5) إضافة is_active لسياسات الأدمن في (الأطباء / فروع العيادات / أقسام العيادات)
--
-- طريقة التشغيل: Supabase → SQL Editor → New query → الصق الملف كله → Run
-- آمن لإعادة التشغيل. لو حصل أي خطأ في النص، مفيش حاجة بتتغير (BEGIN/COMMIT).
-- بعد التشغيل: شغّل استعلام التحقق اللي في آخر الملف، وجرّب الاختبارات.
-- ==========================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) حذف السياسات المكررة
-- ═══════════════════════════════════════════════════════════════════════════
-- بنسيب السياسة العامة (roles = public) لأنها بتغطي الزائر anon
-- وكمان أي حساب مسجّل لو اتفتح موقع العملاء وهو داخل بحسابه.

-- رفع الروشتات: بنشيل النسخة المخصصة لـ anon (سياسة "Allow public prescription upload" تفضل)
DROP POLICY IF EXISTS "Allow customers to upload prescriptions mw9cih_0" ON storage.objects;

-- إدخال الطلبات: بنشيل النسخة المخصصة لـ anon (سياسة "Public insert orders" تفضل)
DROP POLICY IF EXISTS "Allow customers to submit orders" ON public.orders;


-- ═══════════════════════════════════════════════════════════════════════════
-- 4) قراءة order_items و order_status_history
-- ═══════════════════════════════════════════════════════════════════════════
-- قبل: أي مستخدم مسجّل يقرأهم كلهم.
-- بعد: الأدمن، أو صيدلي نشط لطلبات فرعه (أو الطلبات بدون فرع) — نفس منطق orders.

DROP POLICY IF EXISTS "Staff view order items" ON public.order_items;
CREATE POLICY "Staff view order items"
    ON public.order_items
    FOR SELECT
    USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1
            FROM public.orders o
            JOIN public.profiles p ON p.id = auth.uid()
            WHERE o.id = order_items.order_id
              AND p.role = 'pharmacist'
              AND p.is_active = true
              AND (o.branch_id IS NULL OR o.branch_id = p.branch_id)
        )
    );

DROP POLICY IF EXISTS "Staff view status history" ON public.order_status_history;
CREATE POLICY "Staff view status history"
    ON public.order_status_history
    FOR SELECT
    USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1
            FROM public.orders o
            JOIN public.profiles p ON p.id = auth.uid()
            WHERE o.id = order_status_history.order_id
              AND p.role = 'pharmacist'
              AND p.is_active = true
              AND (o.branch_id IS NULL OR o.branch_id = p.branch_id)
        )
    );


-- ═══════════════════════════════════════════════════════════════════════════
-- 5) is_active لأدمن العيادات (أدمن معطّل ما يقدرش يعدّل)
-- ═══════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "p_doctors_all" ON public.doctors;
CREATE POLICY "p_doctors_all"
    ON public.doctors FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_branches_all" ON public.clinic_branches;
CREATE POLICY "p_branches_all"
    ON public.clinic_branches FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
        )
    );

DROP POLICY IF EXISTS "p_categories_all" ON public.clinic_categories;
CREATE POLICY "p_categories_all"
    ON public.clinic_categories FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
        )
    );

COMMIT;


-- ==========================================================================
-- استعلام التحقق (شغّله بعد ما ينجح النص اللي فوق)
-- المفروض:
--   • مفيش "Allow customers to submit orders" على orders
--   • مفيش "Allow customers to upload prescriptions mw9cih_0" على storage.objects
--   • "Staff view order items" و "Staff view status history" شرطهم فيه is_admin() / الفرع
-- ==========================================================================
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies
WHERE (schemaname = 'public'
       AND tablename IN ('orders','order_items','order_status_history',
                         'doctors','clinic_branches','clinic_categories'))
   OR (schemaname = 'storage' AND tablename = 'objects')
ORDER BY schemaname, tablename, policyname;


-- ==========================================================================
-- للرجوع لو حصلت مشكلة (شغّل الجزء اللي محتاجه بس):
-- ==========================================================================
-- CREATE POLICY "Allow customers to upload prescriptions mw9cih_0"
--     ON storage.objects FOR INSERT TO anon
--     WITH CHECK (bucket_id = 'prescriptions');
--
-- CREATE POLICY "Allow customers to submit orders"
--     ON public.orders FOR INSERT TO anon WITH CHECK (true);
--
-- DROP POLICY "Staff view order items" ON public.order_items;
-- CREATE POLICY "Staff view order items" ON public.order_items
--     FOR SELECT USING (auth.role() = 'authenticated');
--
-- DROP POLICY "Staff view status history" ON public.order_status_history;
-- CREATE POLICY "Staff view status history" ON public.order_status_history
--     FOR SELECT USING (auth.role() = 'authenticated');


-- ===== MIGRATION 12 | SOURCE: 13_final.sql =====
-- ==========================================================================
-- 13_final.sql — النسخة النهائية النظيفة من إصلاحات المستوى الثاني (بند 6 و8)
-- ==========================================================================
-- ده ملف مرجعي فقط: بيعكس الحالة النهائية الصح بعد دمج 13 + 13b + 13c
-- مع بعض، من غير ما يعدي بمرحلة الخطأ (الـ infinite recursion) في النص.
-- تشغيله على قاعدة فيها التعديلات دي أصلاً آمن (كله DROP IF EXISTS / OR
-- REPLACE)، مش هيغيّر حاجة عن الوضع الحالي، بس بيوثّق شكل السياسات
-- النهائي الصح في ملف واحد بدل ما تدور بين 3 ملفات.
--
-- لا تشيل 12 / 13 / 13b / 13c — دول أرشيف يوضح إيه اللي حصل وليه (خصوصاً
-- خطأ الـ recursion اللي اتصلح في 13c، عشان محدش يرجع يكرره في تعديل جديد).
-- ==========================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6-أ) orders — تشديد الإدخال العام (بحد العنوان الصحيح: 600 حرف)
-- ═══════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Public insert orders" ON public.orders;
CREATE POLICY "Public insert orders"
    ON public.orders
    FOR INSERT
    WITH CHECK (
        status = 'new'
        AND order_type IN ('delivery', 'pickup')
        AND phone ~ '^01[0125][0-9]{8}$'
        AND char_length(customer_name) BETWEEN 1 AND 100
        AND (address IS NULL OR char_length(address) <= 600)   -- 600: عنوان مجمّع من عدة حقول + GPS
        AND (notes IS NULL OR char_length(notes) <= 200)
        AND (medications IS NULL OR char_length(medications) <= 200)
    );

-- ═══════════════════════════════════════════════════════════════════════════
-- 6-ب) consultations — تشديد الإدخال العام
-- ═══════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Public insert consultations" ON public.consultations;
CREATE POLICY "Public insert consultations"
    ON public.consultations
    FOR INSERT
    WITH CHECK (
        status = 'new'
        AND branch_id IS NULL
        AND outcome IS NULL
        AND outcome_notes IS NULL
        AND followed_up_by IS NULL
        AND followed_up_at IS NULL
        AND phone ~ '^01[0125][0-9]{8}$'
        AND char_length(patient_name) BETWEEN 1 AND 100
        AND (details IS NULL OR char_length(details) <= 200)
    );

-- ═══════════════════════════════════════════════════════════════════════════
-- 6-ج) clinic_appointments — تشديد الإدخال العام
-- ═══════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "p_appointments_insert" ON public.clinic_appointments;
CREATE POLICY "p_appointments_insert"
    ON public.clinic_appointments
    FOR INSERT
    WITH CHECK (
        status = 'new'
        AND visit_fee IS NULL
        AND cancellation_reason IS NULL
        AND patient_phone ~ '^01[0125][0-9]{8}$'
        AND char_length(patient_name) BETWEEN 1 AND 100
        AND (notes IS NULL OR char_length(notes) <= 200)
    );

-- ═══════════════════════════════════════════════════════════════════════════
-- 8-أ) clinic_profiles — تضييق القراءة (بالشكل الآمن من غير recursion)
-- ═══════════════════════════════════════════════════════════════════════════
-- دالة SECURITY DEFINER بتتخطى RLS من جوه، فما تسببش استدعاء متكرر
-- للسياسة اللي هي نفسها بتستخدمها (خطأ 42P17 لو كُتبت كاستعلام مباشر).
CREATE OR REPLACE FUNCTION public.is_clinic_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.clinic_profiles
        WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
    );
$$;

REVOKE ALL ON FUNCTION public.is_clinic_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_clinic_admin() TO authenticated, anon;

DROP POLICY IF EXISTS "p_profiles_select" ON public.clinic_profiles;
CREATE POLICY "p_profiles_select"
    ON public.clinic_profiles
    FOR SELECT
    USING (
        id = auth.uid()
        OR public.is_clinic_admin()
    );

-- ═══════════════════════════════════════════════════════════════════════════
-- 8-ب) تحصين دوال حماية آخر أدمن (SECURITY DEFINER + search_path ثابت)
-- ═══════════════════════════════════════════════════════════════════════════
ALTER FUNCTION public.clinic_protect_last_admin() SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION public.protect_last_active_admin() SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION public.clinic_set_updated_at() SECURITY DEFINER SET search_path = public, pg_temp;

COMMIT;


-- ==========================================================================
-- استعلام التحقق النهائي
-- ==========================================================================
SELECT tablename, policyname, cmd, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('orders','consultations','clinic_appointments','clinic_profiles')
  AND cmd IN ('INSERT','SELECT')
ORDER BY tablename, policyname;

SELECT proname, prosecdef, proconfig
FROM pg_proc
WHERE proname IN ('clinic_protect_last_admin','protect_last_active_admin',
                   'clinic_set_updated_at','is_clinic_admin');


-- ==========================================================================
-- تنبيه للمستقبل (الدرس المستفاد من خطأ 13c):
--   أي سياسة RLS محتاجة تتحقق من "هل المستخدم أدمن" على جدول معين،
--   لازم الفحص يكون عن طريق دالة SECURITY DEFINER منفصلة (زي is_admin()
--   للصيدلية، وis_clinic_admin() هنا للعيادات) — مش استعلام مباشر على
--   نفس الجدول جوه سياسة ذلك الجدول نفسه. استعلام مباشر = خطأ
--   "infinite recursion detected in policy for relation" (42P17).
-- ==========================================================================


-- ==========================================================================
-- للرجوع الكامل لو احتجت (كل الأقسام في ملف واحد):
-- ==========================================================================
-- DROP POLICY "Public insert orders" ON public.orders;
-- CREATE POLICY "Public insert orders" ON public.orders
--     FOR INSERT WITH CHECK (true);
--
-- DROP POLICY "Public insert consultations" ON public.consultations;
-- CREATE POLICY "Public insert consultations" ON public.consultations
--     FOR INSERT WITH CHECK (true);
--
-- DROP POLICY "p_appointments_insert" ON public.clinic_appointments;
-- CREATE POLICY "p_appointments_insert" ON public.clinic_appointments
--     FOR INSERT WITH CHECK (true);
--
-- DROP POLICY "p_profiles_select" ON public.clinic_profiles;
-- CREATE POLICY "p_profiles_select" ON public.clinic_profiles
--     FOR SELECT USING (auth.uid() IS NOT NULL);
--
-- ALTER FUNCTION public.clinic_protect_last_admin() SECURITY INVOKER;
-- ALTER FUNCTION public.protect_last_active_admin() SECURITY INVOKER;
-- ALTER FUNCTION public.clinic_set_updated_at() SECURITY INVOKER;
--
-- DROP FUNCTION IF EXISTS public.is_clinic_admin();


-- ===== MIGRATION 13 | SOURCE: 14_final_create_order.sql =====
-- ==========================================================================
-- 14b_fix_medications_field.sql
-- ==========================================================================
-- تصحيح: create_order كانت بتخزن medications = NULL لو فيه عناصر سلة
-- حقيقية. الكود الأصلي في script.js بيبعت نص خانة "الأدوية والمنتجات
-- المطلوبة" دايماً (سواء كانت متملية تلقائي من السلة أو العميل كتب فيها
-- يدوي)، بغض النظر عن وجود عناصر سلة حقيقية أو لأ. التصحيح: تخزين
-- p_medications_text كما هو دايماً.
--
-- طريقة التشغيل: الصق في SQL Editor وشغّل. آمن لإعادة التشغيل.
-- ==========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.create_order(
    p_customer_name      text,
    p_phone              text,
    p_order_type         text,
    p_branch_id          uuid,
    p_address            text,
    p_notes              text,
    p_prescription_url   text,
    p_medications_text   text,
    p_items              jsonb
)
RETURNS TABLE (
    order_id      bigint,
    tracking_code text,
    subtotal      numeric,
    delivery_fee  numeric,
    total         numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_default_fee    numeric := 25;
    v_free_threshold numeric := 500;
    v_subtotal       numeric := 0;
    v_delivery_fee   numeric := 0;
    v_total          numeric := 0;
    v_tracking       text;
    v_order_id       bigint;
    v_item           jsonb;
    v_product        RECORD;
    v_qty            int;
    v_has_items      boolean;
BEGIN
    IF p_order_type NOT IN ('delivery', 'pickup') THEN
        RAISE EXCEPTION 'نوع الطلب غير صالح';
    END IF;
    IF p_phone !~ '^01[0125][0-9]{8}$' THEN
        RAISE EXCEPTION 'رقم الهاتف غير صالح';
    END IF;
    IF char_length(COALESCE(p_customer_name, '')) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'اسم العميل غير صالح';
    END IF;
    IF p_address IS NOT NULL AND char_length(p_address) > 600 THEN
        RAISE EXCEPTION 'العنوان طويل جداً';
    END IF;
    IF p_notes IS NOT NULL AND char_length(p_notes) > 200 THEN
        RAISE EXCEPTION 'الملاحظات طويلة جداً';
    END IF;
    IF p_order_type = 'delivery' AND p_branch_id IS NULL THEN
        RAISE EXCEPTION 'يجب اختيار الفرع لطلبات التوصيل';
    END IF;

    v_has_items := jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0;

    IF v_has_items THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            v_qty := COALESCE((v_item->>'quantity')::int, 0);
            IF v_qty <= 0 OR v_qty > 100 THEN
                RAISE EXCEPTION 'كمية غير صالحة';
            END IF;

            SELECT id, name_ar, price INTO v_product
            FROM public.products
            WHERE id = (v_item->>'product_id')::uuid
              AND is_active = true AND in_stock = true;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'أحد المنتجات غير متاح حالياً';
            END IF;

            v_subtotal := v_subtotal + (v_product.price * v_qty);
        END LOOP;

        v_tracking := 'AWD-EGY-' || lpad(floor(random() * 90000 + 10000)::text, 5, '0');
    ELSE
        v_subtotal := 0;
        v_tracking := 'AWD-RX-' || lpad(floor(random() * 90000 + 10000)::text, 5, '0');
    END IF;

    SELECT COALESCE((value->>'default_fee')::numeric, 25),
           COALESCE((value->>'free_delivery_threshold')::numeric, 500)
    INTO v_default_fee, v_free_threshold
    FROM public.settings WHERE key = 'delivery_rules';

    IF p_order_type = 'delivery' THEN
        IF v_free_threshold > 0 AND v_subtotal >= v_free_threshold THEN
            v_delivery_fee := 0;
        ELSE
            v_delivery_fee := v_default_fee;
        END IF;
    ELSE
        v_delivery_fee := 0;
    END IF;

    v_total := v_subtotal + v_delivery_fee;

    INSERT INTO public.orders (
        customer_name, phone, medications, delivery_method, address, notes,
        prescription_url, status, tracking_code, branch_id, order_type,
        subtotal, delivery_fee, total
    ) VALUES (
        p_customer_name,
        p_phone,
        p_medications_text,   -- <-- التصحيح: تُخزَّن كما هي دايماً، مش NULL
        CASE WHEN p_order_type = 'delivery' THEN 'توصيل للمنزل' ELSE 'استلام من الصيدلية' END,
        p_address,
        p_notes,
        p_prescription_url,
        'new',
        v_tracking,
        p_branch_id,
        p_order_type,
        v_subtotal,
        v_delivery_fee,
        v_total
    )
    RETURNING id INTO v_order_id;

    IF v_has_items THEN
        INSERT INTO public.order_items (order_id, product_id, product_name_snapshot, quantity, unit_price, total_price)
        SELECT
            v_order_id,
            (item->>'product_id')::uuid,
            p.name_ar,
            (item->>'quantity')::int,
            p.price,
            p.price * (item->>'quantity')::int
        FROM jsonb_array_elements(p_items) item
        JOIN public.products p ON p.id = (item->>'product_id')::uuid;
    END IF;

    RETURN QUERY SELECT v_order_id, v_tracking, v_subtotal, v_delivery_fee, v_total;
END;
$$;

COMMIT;

-- اختبار سريع: كرر نفس استعلام الاختبار اللي جربته قبل كده، وشوف عمود
-- medications في صف orders الجديد — لازم يظهر فيه النص اللي بعتّه.


-- ===== MIGRATION 15 | SOURCE: 15_clinic_patient_files_bucket.sql =====
-- ==========================================================================
-- 15_clinic_patient_files_bucket.sql
-- ==========================================================================
-- يعالج بند 7: فصل ملفات المرضى الطبية (روشتات وتحاليل) عن bucket
-- الأفاتار العام. القرار المتفق عليه:
--   • الملفات القديمة تفضل في clinic-uploads العام زي ما هي (بدون نقل).
--   • الرفعات الجديدة بس (من intake.js) هتروح للـ bucket الجديد الخاص.
--   • صور الأطباء (الأفاتار) تفضل في clinic-uploads العام زي ما هي.
--
-- طريقة التشغيل: الصق في SQL Editor وشغّل. آمن لإعادة التشغيل.
-- ==========================================================================

BEGIN;

-- الـ bucket الجديد: خاص (public = false)، نفس حدود prescriptions بتاع
-- الصيدلية (5MB، نفس الصيغ المسموحة)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'clinic-patient-files', 'clinic-patient-files', false,
    5242880, ARRAY['image/jpeg','image/png','image/webp','application/pdf']
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','application/pdf'];

-- الرفع: أي حساب عيادات نشط (موظف/دكتور/أدمن) — نفس شرط clinic-uploads الحالي
DROP POLICY IF EXISTS "Clinic patient files write" ON storage.objects;
CREATE POLICY "Clinic patient files write"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'clinic-patient-files'
        AND EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- القراءة: حساب عيادات نشط بس (بيتخطى RLS الجدول ده تحديداً — مفيش قارئ عام)
DROP POLICY IF EXISTS "Clinic patient files read" ON storage.objects;
CREATE POLICY "Clinic patient files read"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'clinic-patient-files'
        AND EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- الحذف: أدمن العيادات فقط
DROP POLICY IF EXISTS "Clinic patient files delete" ON storage.objects;
CREATE POLICY "Clinic patient files delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'clinic-patient-files'
        AND EXISTS (
            SELECT 1 FROM public.clinic_profiles
            WHERE id = auth.uid() AND clinic_role = 'clinic_admin' AND is_active = true
        )
    );

COMMIT;

-- تحقق:
SELECT id, public, file_size_limit, allowed_mime_types
FROM storage.buckets WHERE id = 'clinic-patient-files';

SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname LIKE 'Clinic patient files%';


-- ===== MIGRATION 16 | SOURCE: 16_lock_direct_order_insert.sql =====
-- ==========================================================================
-- 16_lock_direct_order_insert.sql   (المرحلة ج — الخطوة الأخيرة في مستوى 3)
-- ==========================================================================
-- دلوقتي الموقع بيستخدم create_order() في الحالتين (السلة والروشتة
-- السريعة)، فمفيش داعي لسياسة الإدخال المباشر العامة على orders. حذفها
-- يقفل الثغرة نهائياً: محدش يقدر يبعت subtotal/total مصنوع بإيده تاني،
-- لأن الطريق الوحيد لإنشاء طلب بقى عن طريق الدالة (اللي بتحسب الأسعار من
-- قاعدة البيانات الحقيقية، مش من المتصفح).
--
-- سياسة "Admin full access orders" (is_admin() ALL) بتفضل زي ما هي، يعني
-- الأدمن لسه يقدر ينشئ/يعدّل طلب يدوي من لوحة التحكم لو احتاج.
--
-- طريقة التشغيل: الصق في SQL Editor وشغّل. آمن لإعادة التشغيل.
-- ==========================================================================

BEGIN;

DROP POLICY IF EXISTS "Public insert orders" ON public.orders;

COMMIT;

-- ==========================================================================
-- تحقق: لازم يفضل بس "Admin full access orders" على INSERT (ومفيش سياسة
-- تانية اسمها Public insert orders)
-- ==========================================================================
SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'orders'
ORDER BY policyname;

-- ==========================================================================
-- اختبار لازم يتعمل بعد التشغيل (من موقع العملاء):
--   1) طلب سلة عادي — لازم يعدي عادي (عن طريق create_order).
--   2) طلب روشتة سريع — لازم يعدي عادي.
--   3) (اختياري، للتأكيد فقط) من Console في المتصفح جرّب:
--        await supabaseClient.from("orders").insert({customer_name:"x", ...})
--      لازم يرجع خطأ صلاحيات (RLS)، مش ينجح.
-- ==========================================================================

-- ==========================================================================
-- للرجوع لو احتجت (يرجّع الوضع القديم المفتوح):
-- ==========================================================================
-- CREATE POLICY "Public insert orders" ON public.orders
--     FOR INSERT WITH CHECK (true);


-- ===== MIGRATION 17 | SOURCE: 17_consultations_branch_lock.sql =====
-- ==========================================================================
-- 17_consultations_branch_lock.sql
-- ==========================================================================
-- المطلوب: الاستشارة الجديدة تظهر لكل الفروع (طول ما branch_id = NULL)،
-- ولحظة ما فرع معيّن يعدّلها فيستلمها بـ branch_id بتاعه، تختفي من عند
-- باقي الفروع. والأدمن يشوف كل حاجة زي دايمًا.
--
-- ─────────────────────────────────────────────────────────────────────────
-- المشكلة:
--   في القاعدة الحقيقية سياسة اسمها "Pharmacist read all consultations"
--   على جدول consultations، شرطها:
--
--       EXISTS (profiles WHERE id = auth.uid()
--               AND role = 'pharmacist' AND is_active = true)
--
--   مفيش فيها أي فلتر على branch_id خالص.
--   يعني أي صيدلي في أي فرع بيشوف استشارات كل الفروع:
--   اسم المريض + رقم التليفون + تفاصيل حالته الصحية.
--
--   وده عكس المطلوب: Frobenius فibrate نفس الجدول فيه سياستين تانيتين
--   ماشيتين بالفلتر الصح:
--     • "Pharmacist branch consultations update"  (فلتر الفرع موجود)
--     • "Admin full access consultations"         (is_admin)
--   يعني التعديل مقيّد صح، والقراءة مفتوحة على السette.
--
--   ─────────────────────────────────────────────────────────────────────────
--   ⚠️  نقطة مهمة: السياسة دي مش موجودة في أي ملف في المشروع.
--       اتعملت يدوي من لوحة Supabase. وأهميتها إن اسمها مش زي الاسم
--       اللي أي ملف بيـ DROP IF EXISTS، فمفيش ترتيب تشغيل للملفات
--       الموجودة يقدر يمسحها — لازم DROP POLICY يدوي.
--       (وده بالظبط السبب إن consultations.js:112 بيشاور على ملف
--        اسمه consultations_branch_lock.sql لحد دلوقتي ولسه مفقود.)
--
-- ─────────────────────────────────────────────────────────────────────────
-- الحل:
--   1) مسح "Pharmacist read all consultations" (اللي مش في المشروع).
--   2) إنشاء "Pharmacist branch consultations read" بنفس منطق
--      schema.sql:377-384، وهو نفس منطق سياسة UPDATE الموجودة بالفعل.
--
--   ليه المنطق ده هو المطلوب بالظبط:
--   ┌──────────────────────────────────────────────────────────────────────┐
--   │  branch_id IS NULL   → لسه ما ات Willsedت من أي فرع                 │
--   │                       → بتظهر لكل الفروع                            │
--   │                       → أول فرع يعدّلها بياخدها                      │
--   │                                                                      │
--   │  branch_id = X       → الفرع X بس هو اللي شايفها                     │
--   │                       → باقي الفارجع مش شايفينها                     │
--   │                       → بتختفي عندهم بمجرد ما تعدّل                   │
--   └──────────────────────────────────────────────────────────────────────┘
--
--   والأدمن: مش محتاج حاجة في السياسة دي. عنده أصلًا
--   "Admin full access consultations" FOR ALL USING (is_admin())، والسياسات
--   بتتجمع بـ OR، فالأسدمن بيشوف كل حاجة لوحده.
--
-- ─────────────────────────────────────────────────────────────────────────
-- التعديل مينفعش يبقى متكرر (Race condition):
--   لحد ما فرع يعدّل، الاستشارة لسه branch_id = NULL ومتاحة للكل، يعني
--   فرعين يقدروا يضغطوا "تأكيد" في نفس اللحظة. ده متوقع، والحماية
--   موجودة في سياسة UPDATE مش هنا:
--
--     • USING على الصف القديم: branch_id IS NULL  →  يمر   ✅
--     • CHECK على الصف الجديد: Postgres بيستخدم نفس USING لو WITH CHECK
--       مش متكتب، فپلازم branch_id = فرع نفسه. يعني محدش يقدر ياخدها
--       لفرع تاني                                                    ❌
--
--   النتيجة: واحد فيهم بس هو اللي بيعدّل، والتاني بياخد رسالة
--   "تم استلام هذه الاستشارة بواسطة فرع آخر" وبيعمل refresh.
--   وده بالظبط اللي consultations.js:443-449 بيقوله من زمان.
--
--   ملاحظة: مفيش trigger ولا عمود محجوز (claim) في القاعدة، فلوearned
--  eeperure عايز "حجز" صريح ومستقل عن التعديل، قول ونعمله بجدول مستقل.
--
-- طريقة التشغيل: الصق في SQL Editor وشغّل. آمن لإعادة التشغيل تماماً.
-- ==========================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) مسح السياسة القديمة (اللي مش في المشروع ومفيش أي ملف بيمسحها)
-- ═══════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Pharmacist read all consultations" ON public.consultations;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) السياسة الصح: بدون فرع + فرعك بس
-- ═══════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Pharmacist branch consultations read" ON public.consultations;
CREATE POLICY "Pharmacist branch consultations read"
    ON public.consultations
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
              AND role = 'pharmacist'
              AND is_active = true
              AND (
                    consultations.branch_id IS NULL
                    OR consultations.branch_id = profiles.branch_id
              )
        )
    );

COMMIT;


-- ==========================================================================
-- تحقق 1: المفروض يطلع صفين على consultations:
--   • "Pharmacist branch consultations read"  (الجديدة)
--   • "Admin full access consultations"       (موجودة من قبل)
--   ومفيش "Pharmacist read all consultations" خالص.
-- ==========================================================================
SELECT policyname, cmd, permissive, roles::text
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'consultations'
ORDER BY cmd, policyname;

-- ==========================================================================
-- تحقق 2: الفلتر موجود فعلاً (لازم يبان branch_id جوه شرط SELECT)
-- ==========================================================================
SELECT policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'consultations'
  AND cmd = 'SELECT';


-- ==========================================================================
-- اختبار لازم يتعمل من متصفح صيدلي بعد التشغيل (مش من SQL):
--
--   1) صيدلي فرع "المعادي" يفتح consultations.html
--      → يشوف الاستشارات الجديدة (branch_id = NULL)              ✅
--      → ما يشوفش استشارة فرع "مدينة نصر" (branch_id تاني)        ❌
--
--   2) من كونسول المتصفح، صيدلي المعادي يعمل update على استشارة
--      لسه ما اتمسكتش:
--        const { data, error } = await supabaseClient
--          .from("consultations")
--          .update({ status: "confirmed", branch_id: "<myBranchId>" })
--          .eq("id", "<theUnclaimedId>")
--          .select("id");
--      → لازم يرجع صف واحد (data.length === 1)                   ✅
--
--   3) بعد الخطوة 2، صيدلي "مدينة نصر" يعمل refresh
--      → لازم تختفي الاستشارة من قائمته                            ✅
--      → ولازم RLS نفسه هو اللي استبعدها، مش بس فلتر العرض في الواجهة
--
--   4) نفس الاستشارة دي على دسكتوب الأدمن
--      → لازم تفضل موجودة                                           ✅
-- ==========================================================================


-- ==========================================================================
-- ملاحظة للرجوع (لو حصلت مشكلة وحبيت ترجع بالظبط):
--
--   ننسخ السطر ده:
--
--   CREATE POLICY "Pharmacist read all consultations"
--       ON public.consultations
--       FOR SELECT
--       USING (
--           EXISTS (
--               SELECT 1 FROM public.profiles
--               WHERE id = auth.uid()
--                 AND role = 'pharmacist'
--                 AND is_active = true
--           )
--       );
--
--   بس الأحسن متعملش كده — ده نفس التسريب اللي إحنا بنصلحه.
--   ولو مضطر، راجع الـ RLS على profiles و customers الأول
--   (لسه وضعهم غير متأكد).
-- ==========================================================================

