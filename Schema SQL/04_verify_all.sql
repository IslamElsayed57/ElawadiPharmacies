-- ==========================================================================
-- 00_verify_setup.sql   (نسخة موسّعة — تحل محل 00_audit_current_policies.sql)
-- ==========================================================================
-- ملف تحقق (READ-ONLY) — لا يُعدّل أي شيء في قاعدة البيانات.
--
-- الهدف: أي شخص أو أي نموذج ذكاء اصطناعي يفتح المشروع ده من غير أي سياق
-- سابق، يقدر يشغّل الملف ده ويقارن الناتج بالتعليقات "متوقع" جنب كل جزء،
-- ويعرف على طول إيه الشغال وإيه لأ، من غير ما حد يشرحله حاجة.
--
-- طريقة التشغيل: انسخ كل قسم لوحده في SQL Editor وشغّله (كل قسم بيرجع
-- نتيجة منفصلة أوضح من نتيجة JSON واحدة مجمّعة).
-- ==========================================================================


-- ══════════════════════════════════════════════════════════════════════════
-- 1) هل RLS مفعّل على كل الجداول الحساسة؟
--    متوقع: rowsecurity = true على كل صف
-- ══════════════════════════════════════════════════════════════════════════
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
      'orders','order_items','order_status_history','settings','customers',
      'consultations','clinic_patients','clinic_prescriptions',
      'clinic_appointments','clinic_profiles','products','categories',
      'branches','clinic_branches','clinic_categories','doctors',
      'rate_limit_log','profiles'
  )
ORDER BY tablename;


-- ══════════════════════════════════════════════════════════════════════════
-- 2) دوال الأمان (SECURITY DEFINER) — لازم كلها prosecdef = true
--    وproconfig يحتوي على search_path=public, pg_temp
-- ══════════════════════════════════════════════════════════════════════════
-- متوقع لكل صف: prosecdef = true, proconfig يحتوي على "search_path=public, pg_temp"
SELECT proname, prosecdef, proconfig
FROM pg_proc
WHERE proname IN (
    'is_admin',                              -- الصيدلية: هل المستخدم أدمن
    'get_user_branch',                       -- الصيدلية: فرع المستخدم
    'is_clinic_admin',                       -- العيادات: هل المستخدم أدمن (بديل عن استعلام مباشر لمنع recursion)
    'clinic_protect_last_admin',             -- يمنع تعطيل آخر أدمن عيادات
    'protect_last_active_admin',             -- يمنع تعطيل آخر أدمن صيدلية
    'clinic_set_updated_at',
    'check_rate_limit',                      -- محدود الاستدعاء (REVOKE من anon/authenticated)
    'rate_limit_orders',
    'rate_limit_consultations',
    'rate_limit_appointments',
    'protect_clinic_profiles_sensitive_columns',
    'recalculate_order_total',               -- يحسب total من subtotal+delivery_fee سيرفريًا
    'create_order'                           -- المسار الوحيد لإنشاء طلب (يحسب الأسعار من products الحقيقية)
)
ORDER BY proname;

-- تحقق إضافي: create_order لازم تكون موجودة وبنفس التوقيع ده بالظبط
-- (9 معاملات). لو مش ظاهرة هنا، يبقى لسه ما اتعملتش أو اتحذفت غلط.
SELECT pg_get_function_identity_arguments(oid) AS signature
FROM pg_proc WHERE proname = 'create_order';


-- ══════════════════════════════════════════════════════════════════════════
-- 3) هل check_rate_limit محمية من الاستدعاء المباشر (RPC) من العميل؟
--    متوقع: مفيش أي صف فيه grantee = anon أو authenticated
-- ══════════════════════════════════════════════════════════════════════════
SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'check_rate_limit';


-- ══════════════════════════════════════════════════════════════════════════
-- 4) سياسات الجداول الحرجة — القراءة والإدخال
--    شوف التعليقات جنب كل سطر للمتوقع
-- ══════════════════════════════════════════════════════════════════════════
SELECT tablename, policyname, cmd, roles::text, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
      'orders','order_items','order_status_history','consultations',
      'clinic_appointments','clinic_profiles','clinic_patients',
      'clinic_prescriptions','doctors','clinic_branches','clinic_categories','profiles','rate_limit_log'
  )
ORDER BY tablename, policyname;

-- ─── نقاط التحقق الأساسية من نتيجة الاستعلام فوق ───
-- • orders: السياسة العامة للإدخال غائبة بعد migration 16، والإنشاء عبر create_order() فقط.
-- • consultations: INSERT مقيد من migration 13؛ SELECT للصيدلي مقيد بالفرع من migration 17.
-- • clinic_appointments: INSERT يفرض الحالة والحقول الابتدائية من migration 13.
-- • order_items: سياسة SELECT اسمها "Staff view order items" بتتحقق من
--   is_admin() أو صيدلي فرعه (مش auth.role()='authenticated' بس).
-- • order_status_history: نفس الشيء لسياسة "Staff view status history".
-- • clinic_profiles: سياسة SELECT اسمها "p_profiles_select" وشرطها
--   (qual) = "(id = auth.uid()) OR is_clinic_admin()" — لازم تستخدم
--   الدالة is_clinic_admin()، مش استعلام subquery مباشر على نفس الجدول
--   (استعلام مباشر = خطأ infinite recursion 42P17).
-- • doctors / clinic_branches / clinic_categories: سياسات "*_all"
--   (الأدمن) لازم تتضمن "is_active = true" في شرطها.


-- ══════════════════════════════════════════════════════════════════════════
-- 5) Storage buckets — الإعدادات والصلاحيات
-- ══════════════════════════════════════════════════════════════════════════
SELECT id, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id IN ('clinic-uploads', 'clinic-patient-files', 'prescriptions', 'product-images')
ORDER BY id;

-- متوقع:
-- • clinic-uploads:      public = true   (أفاتار الأطباء وتوقيعهم — عام)
-- • clinic-patient-files: public = false  (روشتات وتحاليل المرضى — خاص)
-- • prescriptions:       public = false  (روشتات الصيدلية — خاص)
-- • product-images:      public = true   (صور المنتجات — عام)
-- • الأربعة: file_size_limit = 5242880 (5MB)

SELECT policyname, cmd, roles::text
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
ORDER BY policyname;

-- نقاط تحقق:
-- • لازم يكون فيه سياسة SELECT واحدة بس لـ prescriptions (اسمها "Allow
--   authenticated staff view prescriptions") — مفيش قارئ عام.
-- • لازم يكون فيه بالظبط سياسة INSERT واحدة لرفع prescriptions من
--   الزوار (مش سياستين مكررتين).
-- • clinic-patient-files: سياسات write/read/delete؛ افحص عدم وجود سياسات إضافية، والقراءة
--   مقصورة على clinic_profiles نشط (مفيش قارئ عام).


-- ══════════════════════════════════════════════════════════════════════════
-- 6) اختبار حي لـ create_order (اختياري - بيعمل صف تجريبي فعلي)
--    شيل التعليق وحط id منتج حقيقي لو عايز تتأكد عملي
-- ══════════════════════════════════════════════════════════════════════════
-- SELECT * FROM public.create_order(
--     'اختبار تحقق', '01012345678', 'pickup', NULL, NULL, NULL, NULL, NULL,
--     '[{"product_id": "<ضع id منتج حقيقي هنا>", "quantity": 1}]'::jsonb
-- );
-- متوقع: يرجع صف فيه subtotal = سعر المنتج بالظبط (تحقق من هذا يدويًا
-- بمقارنته بـ SELECT price FROM products WHERE id = '<نفس الـ id>').


-- ══════════════════════════════════════════════════════════════════════════
-- ملخص الحالة المتوقعة (لو كل الأقسام فوق طابقت المتوقع):
-- ══════════════════════════════════════════════════════════════════════════
-- ✅ كل الجداول الحساسة عليها RLS مفعّل.
-- ✅ كل دوال "فحص الأدمن" و"حماية آخر أدمن" DEFINER + search_path ثابت.
-- ✅ create_order() موجودة وهي المسار الوحيد لإنشاء طلب (السعر يُحسب
--    سيرفريًا من products/settings، مش من المتصفح).
-- ✅ الإدخال العام (orders/consultations/clinic_appointments) مقيّد
--    بحقول إجبارية وطول أقصى وصيغة هاتف، مش WITH CHECK(true) مفتوح.
-- ✅ ملفات المرضى الطبية (روشتات/تحاليل) في bucket خاص signed-URL-only،
--    والأفاتار وصور المنتجات في buckets عامة منفصلة.
-- ✅ clinic_profiles قراءتها مقصورة على صف المستخدم + الأدمن، من غير
--    أي infinite recursion.
--
-- ملاحظة: هذا الملف لا يتحقق من ملفات الواجهة (JS) — راجع
-- PROJECT_STATUS.md لملخص إصلاحات XSS وملفات الواجهة المعدّلة.
-- ==========================================================================
