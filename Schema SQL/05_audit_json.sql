-- ==========================================================================
-- 00_audit_current_policies.sql  (v2 — استعلام واحد يرجّع كل شيء)
-- ملف تحقق (READ-ONLY) — لا يُعدّل أي شيء في قاعدة البيانات
-- --------------------------------------------------------------------------
-- التعليمات:
--   1. انسخ هذا الملف كاملاً في Supabase SQL Editor
--   2. اضغط RUN  ← هيطلع صف واحد عمود واحد (JSON)
--   3. اضغط على الخلية → Copy  أو  Export → CSV
--   4. ألصقه لي هنا
-- ==========================================================================

SELECT jsonb_build_object(

  -- 1) سياسات RLS على الجداول العامة
  'public_policies', (
    SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.tablename, t.policyname)
    FROM (
      SELECT schemaname, tablename, policyname, permissive, roles::text, cmd, qual, with_check
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename IN (
          'orders','order_items','order_status_history','settings',
          'clinic_patients','clinic_prescriptions','clinic_appointments','clinic_profiles',
          'products','categories','branches','clinic_branches','doctors','consultations'
        )
      ORDER BY tablename, policyname
    ) t
  ),

  -- 2) سياسات storage.objects
  'storage_policies', (
    SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.policyname)
    FROM (
      SELECT schemaname, tablename, policyname, permissive, roles::text, cmd, qual, with_check
      FROM pg_policies
      WHERE schemaname = 'storage' AND tablename = 'objects'
      ORDER BY policyname
    ) t
  ),

  -- 3a) حالة RLS على كل جدول
  'rls_enabled', (
    SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.tablename)
    FROM (
      SELECT schemaname, tablename, rowsecurity
      FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename IN (
          'orders','order_items','order_status_history','settings',
          'clinic_patients','clinic_prescriptions','clinic_appointments','clinic_profiles',
          'products','categories','branches','clinic_branches','doctors','consultations'
        )
      ORDER BY tablename
    ) t
  ),

  -- 3b) أعمدة الجداول المهمة
  'columns', (
    SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.table_name, t.ordinal_position)
    FROM (
      SELECT table_name, column_name, data_type, is_nullable, column_default, ordinal_position
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name IN ('clinic_profiles','doctors','clinic_patients','clinic_appointments','clinic_prescriptions')
      ORDER BY table_name, ordinal_position
    ) t
  ),

  -- 3c) الدوال المساعدة
  'functions', (
    SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.routine_name)
    FROM (
      SELECT routine_name, routine_type, security_type, data_type AS return_type
      FROM information_schema.routines
      WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
      ORDER BY routine_name
    ) t
  ),

  -- 3d) الـ triggers على orders / order_items
  'triggers', (
    SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.event_object_table, t.trigger_name)
    FROM (
      SELECT trigger_name, event_manipulation, event_object_table, action_timing, action_statement
      FROM information_schema.triggers
      WHERE trigger_schema = 'public'
        AND event_object_table IN ('orders','order_items')
      ORDER BY event_object_table, trigger_name
    ) t
  ),

  -- 3e) إعدادات storage buckets
  'buckets', (
    SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.id)
    FROM (
      SELECT id, name, public, file_size_limit, allowed_mime_types
      FROM storage.buckets
      WHERE id IN ('prescriptions','product-images','clinic-uploads')
      ORDER BY id
    ) t
  )

) AS full_audit;

-- ==========================================================================
-- ✅ اضغط على الخلية الناتجة → Copy → ألصقها لي كاملة
-- ==========================================================================
