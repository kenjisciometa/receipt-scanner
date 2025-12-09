

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "auth";


ALTER SCHEMA "auth" OWNER TO "supabase_admin";


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'Split Bill cleanup completed - removed unused tables, functions, views, and columns';



CREATE SCHEMA IF NOT EXISTS "storage";


ALTER SCHEMA "storage" OWNER TO "supabase_admin";


CREATE TYPE "auth"."aal_level" AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


ALTER TYPE "auth"."aal_level" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."code_challenge_method" AS ENUM (
    's256',
    'plain'
);


ALTER TYPE "auth"."code_challenge_method" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."factor_status" AS ENUM (
    'unverified',
    'verified'
);


ALTER TYPE "auth"."factor_status" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."factor_type" AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


ALTER TYPE "auth"."factor_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_authorization_status" AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


ALTER TYPE "auth"."oauth_authorization_status" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_client_type" AS ENUM (
    'public',
    'confidential'
);


ALTER TYPE "auth"."oauth_client_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_registration_type" AS ENUM (
    'dynamic',
    'manual'
);


ALTER TYPE "auth"."oauth_registration_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_response_type" AS ENUM (
    'code'
);


ALTER TYPE "auth"."oauth_response_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."one_time_token_type" AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


ALTER TYPE "auth"."one_time_token_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "public"."alert_type" AS ENUM (
    'low_stock',
    'out_of_stock',
    'expiring',
    'system'
);


ALTER TYPE "public"."alert_type" OWNER TO "postgres";


CREATE TYPE "public"."billing_status" AS ENUM (
    'draft',
    'open',
    'paid',
    'uncollectible',
    'void'
);


ALTER TYPE "public"."billing_status" OWNER TO "postgres";


CREATE TYPE "public"."device_type" AS ENUM (
    'pos',
    'kitchen',
    'management',
    'display',
    'printer'
);


ALTER TYPE "public"."device_type" OWNER TO "postgres";


CREATE TYPE "public"."modification_status" AS ENUM (
    'pending',
    'completed',
    'cancelled',
    'failed'
);


ALTER TYPE "public"."modification_status" OWNER TO "postgres";


CREATE TYPE "public"."modification_type" AS ENUM (
    'item_add',
    'item_remove',
    'item_modify',
    'discount_add',
    'discount_remove',
    'refund_partial',
    'refund_full',
    'note_add'
);


ALTER TYPE "public"."modification_type" OWNER TO "postgres";


CREATE TYPE "public"."order_status" AS ENUM (
    'pending',
    'processing',
    'completed',
    'cancelled',
    'refunded',
    'unpaid'
);


ALTER TYPE "public"."order_status" OWNER TO "postgres";


CREATE TYPE "public"."organization_lifecycle_status" AS ENUM (
    'active',
    'closing',
    'closed',
    'deleted'
);


ALTER TYPE "public"."organization_lifecycle_status" OWNER TO "postgres";


CREATE TYPE "public"."payment_flow_type" AS ENUM (
    'normal',
    'split'
);


ALTER TYPE "public"."payment_flow_type" OWNER TO "postgres";


CREATE TYPE "public"."payment_method" AS ENUM (
    'cash',
    'card',
    'digital_wallet',
    'gift_card',
    'store_credit'
);


ALTER TYPE "public"."payment_method" OWNER TO "postgres";


CREATE TYPE "public"."product_status" AS ENUM (
    'active',
    'inactive',
    'out_of_stock'
);


ALTER TYPE "public"."product_status" OWNER TO "postgres";


CREATE TYPE "public"."subscription_status" AS ENUM (
    'active',
    'canceled',
    'incomplete',
    'incomplete_expired',
    'past_due',
    'trialing',
    'unpaid'
);


ALTER TYPE "public"."subscription_status" OWNER TO "postgres";


CREATE TYPE "public"."transaction_type" AS ENUM (
    'sale',
    'refund',
    'adjustment',
    'transfer',
    'void'
);


ALTER TYPE "public"."transaction_type" OWNER TO "postgres";


CREATE TYPE "public"."user_access_role" AS ENUM (
    'admin',
    'manager',
    'cashier',
    'viewer'
);


ALTER TYPE "public"."user_access_role" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'owner',
    'admin',
    'manager',
    'cashier'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "storage"."buckettype" AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


ALTER TYPE "storage"."buckettype" OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "auth"."email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


ALTER FUNCTION "auth"."email"() OWNER TO "supabase_auth_admin";


COMMENT ON FUNCTION "auth"."email"() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';



CREATE OR REPLACE FUNCTION "auth"."jwt"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


ALTER FUNCTION "auth"."jwt"() OWNER TO "supabase_auth_admin";


CREATE OR REPLACE FUNCTION "auth"."role"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


ALTER FUNCTION "auth"."role"() OWNER TO "supabase_auth_admin";


COMMENT ON FUNCTION "auth"."role"() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';



CREATE OR REPLACE FUNCTION "auth"."uid"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


ALTER FUNCTION "auth"."uid"() OWNER TO "supabase_auth_admin";


COMMENT ON FUNCTION "auth"."uid"() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';



CREATE OR REPLACE FUNCTION "public"."audit_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    audit_user_id uuid;
BEGIN
    -- Get the user_id from public.users table that matches auth.uid()
    -- If the user doesn't exist yet in public.users, use NULL
    SELECT id INTO audit_user_id 
    FROM public.users 
    WHERE id = auth.uid();
    
    -- If no matching user found in public.users, set to NULL
    -- This can happen during user registration when triggers fire before user creation completes
    IF audit_user_id IS NULL THEN
        audit_user_id := NULL;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, record_id, operation, old_data, user_id)
        VALUES (TG_TABLE_NAME, OLD.id, TG_OP, row_to_json(OLD), audit_user_id);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, record_id, operation, old_data, new_data, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, row_to_json(OLD), row_to_json(NEW), audit_user_id);
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, record_id, operation, new_data, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, row_to_json(NEW), audit_user_id);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."audit_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."broadcast_new_order"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Only broadcast orders with kitchen_status = 'pending'
  IF NEW.kitchen_status = 'pending' THEN
    -- Notify realtime channel
    PERFORM pg_notify(
      'order_channel', 
      json_build_object(
        'event', 'new_order',
        'order_id', NEW.id,
        'store_id', NEW.store_id,
        'kitchen_status', NEW.kitchen_status,
        'table', 'orders',
        'type', 'INSERT'
      )::text
    );
    
    -- Log for debugging
    RAISE LOG 'Broadcasting new pending order: %', NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."broadcast_new_order"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."broadcast_order_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Broadcast when kitchen_status changes
  IF OLD.kitchen_status != NEW.kitchen_status THEN
    PERFORM pg_notify(
      'order_channel', 
      json_build_object(
        'event', 'order_status_changed',
        'order_id', NEW.id,
        'store_id', NEW.store_id,
        'old_kitchen_status', OLD.kitchen_status,
        'new_kitchen_status', NEW.kitchen_status,
        'table', 'orders',
        'type', 'UPDATE'
      )::text
    );
    
    RAISE LOG 'Broadcasting order status change: % from % to %', NEW.id, OLD.kitchen_status, NEW.kitchen_status;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."broadcast_order_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."change_log_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    change_data JSONB;
BEGIN
    IF TG_OP = 'DELETE' THEN
        change_data = row_to_json(OLD);
        INSERT INTO change_logs (table_name, record_id, operation, data)
        VALUES (TG_TABLE_NAME, OLD.id, TG_OP, change_data);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        change_data = row_to_json(NEW);
        INSERT INTO change_logs (table_name, record_id, operation, data)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, change_data);
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        change_data = row_to_json(NEW);
        INSERT INTO change_logs (table_name, record_id, operation, data)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, change_data);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."change_log_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_admin_role_for_storage"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('owner', 'admin', 'manager')
    );
END;
$$;


ALTER FUNCTION "public"."check_admin_role_for_storage"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_kds_triggers"() RETURNS TABLE("trigger_name" "text", "table_name" "text", "function_name" "text", "status" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.trigger_name::text,
        t.event_object_table::text,
        t.action_statement::text,
        CASE WHEN t.trigger_name IS NOT NULL THEN 'ACTIVE' ELSE 'MISSING' END::text
    FROM information_schema.triggers t
    WHERE t.trigger_name IN ('kds_orders_insert_trigger', 'kds_orders_update_trigger', 'kds_orders_delete_trigger')
    AND t.trigger_schema = 'public';
END;
$$;


ALTER FUNCTION "public"."check_kds_triggers"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_upload_organization_path"("file_path" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    user_org_id uuid;
    file_org_id text;
BEGIN
    -- 認証されたユーザーの組織IDを取得
    SELECT organization_id INTO user_org_id 
    FROM users 
    WHERE id = auth.uid();
    
    -- ファイルパスの最初の部分が組織IDと一致するかチェック
    file_org_id := split_part(file_path, '/', 1);
    
    RETURN user_org_id IS NOT NULL AND user_org_id::text = file_org_id;
END;
$$;


ALTER FUNCTION "public"."check_upload_organization_path"("file_path" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_user_organization_storage_access"("file_path" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    user_org_id uuid;
    file_org_id text;
BEGIN
    -- 認証されたユーザーの組織IDを取得
    SELECT organization_id INTO user_org_id 
    FROM users 
    WHERE id = auth.uid();
    
    -- ファイルパスから組織IDを抽出（organization_id/... の形式を想定）
    file_org_id := split_part(file_path, '/', 1);
    
    -- ユーザーの組織IDとファイルの組織IDが一致するかチェック
    RETURN user_org_id::text = file_org_id;
END;
$$;


ALTER FUNCTION "public"."check_user_organization_storage_access"("file_path" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_audit_logs"("days_to_keep" integer DEFAULT 90) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs
    WHERE created_at < NOW() - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_audit_logs"("days_to_keep" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_cds_carts"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM cds_carts 
  WHERE expires_at < NOW() 
  OR status IN ('completed', 'cancelled');
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RAISE NOTICE 'Cleaned up % expired CDS cart records', deleted_count;
  RETURN deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_cds_carts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_cds_sessions"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Delete expired or inactive sessions
  DELETE FROM customer_display_sessions 
  WHERE expires_at < NOW() 
     OR active = false;
     
  RAISE NOTICE 'Cleaned up expired CDS sessions';
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_cds_sessions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_sessions"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  expired_count INTEGER;
BEGIN
  -- Mark expired active sessions as inactive
  UPDATE customer_display_sessions
  SET active = false, updated_at = NOW()
  WHERE active = true 
  AND expires_at < NOW();

  GET DIAGNOSTICS expired_count = ROW_COUNT;
  
  -- Delete old inactive sessions (older than 1 day for ephemeral design)
  DELETE FROM customer_display_sessions
  WHERE active = false 
  AND updated_at < NOW() - INTERVAL '1 day';

  RETURN expired_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_sessions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_kds_test_data"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    DELETE FROM orders WHERE order_number LIKE 'TEST-%';
    RAISE NOTICE 'Cleaned up KDS test data';
END;
$$;


ALTER FUNCTION "public"."cleanup_kds_test_data"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_old_cds_sessions"("older_than_hours" integer DEFAULT 1) RETURNS TABLE("deleted_count" integer)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  count_deleted INTEGER;
BEGIN
  WITH deleted AS (
    DELETE FROM customer_display_sessions 
    WHERE created_at < NOW() - INTERVAL '1 hour' * older_than_hours
       OR (expires_at IS NOT NULL AND expires_at < NOW())
       OR active = false
    RETURNING id
  )
  SELECT COUNT(*)::INTEGER INTO count_deleted FROM deleted;
  
  RAISE NOTICE 'Cleaned up % expired CDS sessions', count_deleted;
  RETURN QUERY SELECT count_deleted;
END;
$$;


ALTER FUNCTION "public"."cleanup_old_cds_sessions"("older_than_hours" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_stale_persistent_sessions"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Mark sessions as disconnected if no heartbeat for 5 minutes
  UPDATE cds_sessions
  SET 
    status = 'disconnected',
    last_disconnect_reason = 'Heartbeat timeout'
  WHERE 
    is_persistent = true 
    AND status = 'active'
    AND last_heartbeat_at < now() - INTERVAL '5 minutes';
    
  -- Update device connection states
  UPDATE cds_devices
  SET connection_state = 'disconnected'
  WHERE 
    connection_state = 'connected'
    AND last_heartbeat_at < now() - INTERVAL '5 minutes';
    
  -- Close stale connection records
  UPDATE persistent_session_connections
  SET 
    disconnected_at = now(),
    disconnect_reason = 'Heartbeat timeout'
  WHERE 
    disconnected_at IS NULL
    AND connected_at < now() - INTERVAL '5 minutes'
    AND NOT EXISTS (
      SELECT 1 FROM cds_sessions s 
      WHERE s.id = persistent_session_connections.session_id 
      AND s.last_heartbeat_at > now() - INTERVAL '5 minutes'
    );
    
  -- Archive old expired sessions (older than 30 days)
  UPDATE cds_sessions
  SET status = 'cancelled'
  WHERE 
    is_persistent = true
    AND connection_expires_at < now()
    AND status != 'cancelled';
END;
$$;


ALTER FUNCTION "public"."cleanup_stale_persistent_sessions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_synced_change_logs"("days_to_keep" integer DEFAULT 7) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM change_logs
    WHERE synced_at IS NOT NULL
    AND synced_at < NOW() - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_synced_change_logs"("days_to_keep" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_cds_order"("p_display_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Clear cart data and mark as completed
  UPDATE customer_display_sessions 
  SET 
    cart_data = NULL,
    order_totals = NULL,
    active = false,
    expires_at = NOW() -- Expire immediately
  WHERE display_id = p_display_id AND active = true;
END;
$$;


ALTER FUNCTION "public"."complete_cds_order"("p_display_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_order_and_cleanup"("p_display_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Mark session as inactive and clear cart data
  UPDATE customer_display_sessions 
  SET 
    active = false,
    cart_data = NULL,
    order_totals = NULL,
    expires_at = NOW(), -- Expire immediately
    updated_at = NOW()
  WHERE display_id = p_display_id AND active = true;
  
  -- Cleanup expired sessions while we're at it
  PERFORM cleanup_expired_cds_sessions();
  
  -- Log completion
  RAISE NOTICE 'Order completed for display %, session marked for cleanup', p_display_id;
END;
$$;


ALTER FUNCTION "public"."complete_order_and_cleanup"("p_display_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."connect_to_persistent_session"("p_session_token" "text", "p_device_id" "text", "p_device_token" "text" DEFAULT NULL::"text", "p_ip_address" "inet" DEFAULT NULL::"inet", "p_user_agent" "text" DEFAULT NULL::"text") RETURNS TABLE("success" boolean, "session_id" "uuid", "message" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  target_session_id uuid;
  current_status text;
BEGIN
  -- Find active persistent session
  SELECT id, status INTO target_session_id, current_status
  FROM cds_sessions 
  WHERE session_token = p_session_token 
    AND is_persistent = true
    AND (connection_expires_at IS NULL OR connection_expires_at > now());
  
  IF target_session_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Session not found or expired'::text;
    RETURN;
  END IF;
  
  -- Update session with connection info
  UPDATE cds_sessions 
  SET 
    status = 'active',
    last_heartbeat_at = now(),
    connection_count = connection_count + 1
  WHERE id = target_session_id;
  
  -- Update or create device record
  INSERT INTO cds_devices (
    organization_id,
    store_id,
    device_id,
    device_token,
    persistent_session_id,
    last_seen_at,
    last_heartbeat_at,
    connection_state,
    reconnection_attempts
  ) 
  SELECT 
    s.organization_id,
    s.store_id,
    p_device_id,
    p_device_token,
    target_session_id,
    now(),
    now(),
    'connected',
    0
  FROM cds_sessions s WHERE s.id = target_session_id
  ON CONFLICT (device_id) DO UPDATE SET
    device_token = EXCLUDED.device_token,
    persistent_session_id = EXCLUDED.persistent_session_id,
    last_seen_at = now(),
    last_heartbeat_at = now(),
    connection_state = 'connected',
    reconnection_attempts = 0;
  
  -- Log connection
  INSERT INTO persistent_session_connections (
    session_id,
    device_id,
    ip_address,
    user_agent
  ) VALUES (
    target_session_id,
    p_device_id,
    p_ip_address,
    p_user_agent
  );
  
  -- Log state change if status changed
  IF current_status != 'active' THEN
    INSERT INTO session_state_changes (
      session_id,
      previous_state,
      new_state,
      changed_by,
      change_reason
    ) VALUES (
      target_session_id,
      current_status,
      'active',
      'cds',
      'Device connected to persistent session'
    );
  END IF;
  
  RETURN QUERY SELECT true, target_session_id, 'Connected successfully'::text;
END;
$$;


ALTER FUNCTION "public"."connect_to_persistent_session"("p_session_token" "text", "p_device_id" "text", "p_device_token" "text", "p_ip_address" "inet", "p_user_agent" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_persistent_session"("p_organization_id" "uuid", "p_store_id" "uuid", "p_table_number" integer DEFAULT NULL::integer, "p_device_id" "text" DEFAULT NULL::"text") RETURNS TABLE("session_id" "uuid", "session_token" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  new_session_id uuid;
  new_session_token text;
BEGIN
  -- Generate session token
  new_session_token := generate_session_token();
  
  -- Create persistent session
  INSERT INTO cds_sessions (
    organization_id,
    store_id,
    table_number,
    session_token,
    status,
    is_persistent,
    auto_reconnect,
    connection_expires_at,
    session_data
  ) VALUES (
    p_organization_id,
    p_store_id,
    p_table_number,
    new_session_token,
    'active',
    true,
    true,
    now() + INTERVAL '30 days', -- Default 30-day expiration
    '{}'::jsonb
  ) RETURNING id INTO new_session_id;

  -- Log state change
  INSERT INTO session_state_changes (
    session_id,
    previous_state,
    new_state,
    changed_by,
    change_reason
  ) VALUES (
    new_session_id,
    NULL,
    'active',
    'system',
    'Persistent session created'
  );

  RETURN QUERY SELECT new_session_id, new_session_token;
END;
$$;


ALTER FUNCTION "public"."create_persistent_session"("p_organization_id" "uuid", "p_store_id" "uuid", "p_table_number" integer, "p_device_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_test_user_with_org"("user_email" "text", "user_name" "text" DEFAULT NULL::"text", "org_name" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    new_org_id uuid;
    result json;
BEGIN
    -- Create organization first
    INSERT INTO organizations (name, created_at, updated_at)
    VALUES (
        COALESCE(org_name, user_email || '''s Organization'),
        NOW(),
        NOW()
    )
    RETURNING id INTO new_org_id;
    
    -- Create user profile (this will be called after auth.users insert)
    result := json_build_object(
        'organization_id', new_org_id,
        'email', user_email,
        'name', COALESCE(user_name, user_email),
        'success', true
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'error', SQLERRM,
            'success', false
        );
END;
$$;


ALTER FUNCTION "public"."create_test_user_with_org"("user_email" "text", "user_name" "text", "org_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cross_tab_insert_product"("p_source_tab_id" "uuid", "p_target_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  source_order INTEGER;
  max_target_position INTEGER;
BEGIN
  -- 入力値検証
  IF p_insert_position < 1 THEN
    p_insert_position := 1;
  END IF;

  -- タブの存在確認
  IF NOT EXISTS (SELECT 1 FROM product_tabs WHERE id = p_source_tab_id) THEN
    RAISE EXCEPTION 'Source tab not found';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM product_tabs WHERE id = p_target_tab_id) THEN
    RAISE EXCEPTION 'Target tab not found';
  END IF;

  -- 移動元の商品位置を取得
  SELECT display_order INTO source_order
  FROM product_tab_items
  WHERE tab_id = p_source_tab_id AND product_id = p_product_id;

  IF source_order IS NULL THEN
    RAISE EXCEPTION 'Product not found in source tab';
  END IF;

  -- 挿入位置の調整（ターゲットタブの最大位置を超えないように）
  SELECT COALESCE(MAX(display_order), 0) + 1 INTO max_target_position
  FROM product_tab_items
  WHERE tab_id = p_target_tab_id;

  IF p_insert_position > max_target_position THEN
    p_insert_position := max_target_position;
  END IF;

  -- 移動元タブ: 後続商品を詰める
  UPDATE product_tab_items
  SET display_order = display_order - 1
  WHERE tab_id = p_source_tab_id
    AND display_order > source_order;

  -- 移動先タブ: 挿入位置以降をシフト
  UPDATE product_tab_items
  SET display_order = display_order + 1
  WHERE tab_id = p_target_tab_id
    AND display_order >= p_insert_position;

  -- 商品のタブ移動と位置設定
  UPDATE product_tab_items
  SET tab_id = p_target_tab_id, display_order = p_insert_position
  WHERE product_id = p_product_id;

  -- 両タブのdisplay_orderを正規化
  PERFORM normalize_display_orders(p_source_tab_id);
  PERFORM normalize_display_orders(p_target_tab_id);

  RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."cross_tab_insert_product"("p_source_tab_id" "uuid", "p_target_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."disconnect_from_persistent_session"("p_session_id" "uuid", "p_device_id" "text", "p_is_manual" boolean DEFAULT false, "p_reason" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  connection_record_id uuid;
BEGIN
  -- Update device state
  UPDATE cds_devices 
  SET 
    connection_state = 'disconnected',
    last_seen_at = now()
  WHERE device_id = p_device_id AND persistent_session_id = p_session_id;
  
  -- Close current connection record
  UPDATE persistent_session_connections 
  SET 
    disconnected_at = now(),
    disconnect_reason = p_reason,
    is_manual_disconnect = p_is_manual
  WHERE session_id = p_session_id 
    AND device_id = p_device_id 
    AND disconnected_at IS NULL;
  
  -- Update session if manually disconnected
  IF p_is_manual THEN
    UPDATE cds_sessions 
    SET 
      status = 'disconnected',
      manual_disconnect = true,
      last_disconnect_reason = p_reason
    WHERE id = p_session_id;
    
    -- Log state change
    INSERT INTO session_state_changes (
      session_id,
      previous_state,
      new_state,
      changed_by,
      change_reason
    ) VALUES (
      p_session_id,
      'active',
      'disconnected',
      'cds',
      COALESCE(p_reason, 'Manual disconnect from CDS')
    );
  END IF;
  
  RETURN true;
END;
$$;


ALTER FUNCTION "public"."disconnect_from_persistent_session"("p_session_id" "uuid", "p_device_id" "text", "p_is_manual" boolean, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."exec_sql"("sql" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  result json;
begin
  execute format('select json_agg(t) from (%s) t', sql) into result;
  return result;
end;
$$;


ALTER FUNCTION "public"."exec_sql"("sql" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."extract_org_id_from_path"("file_path" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Extract organization_id from path like "org_id/filename.ext"
  IF file_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/' THEN
    RETURN (split_part(file_path, '/', 1))::uuid;
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."extract_org_id_from_path"("file_path" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fix_user_profile"("p_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_org_id UUID;
BEGIN
    -- Find user's organization
    SELECT organization_id INTO v_org_id
    FROM users 
    WHERE id = p_user_id;
    
    IF v_org_id IS NULL THEN
        -- Try to find organization through store roles
        SELECT s.organization_id INTO v_org_id
        FROM user_store_roles usr
        JOIN stores s ON usr.store_id = s.id
        WHERE usr.user_id = p_user_id
        AND usr.is_active = true
        LIMIT 1;
        
        IF v_org_id IS NOT NULL THEN
            -- Update user with found organization
            UPDATE users 
            SET organization_id = v_org_id, updated_at = NOW()
            WHERE id = p_user_id;
        END IF;
    END IF;
    
    RETURN json_build_object(
        'user_id', p_user_id,
        'organization_id', v_org_id,
        'success', v_org_id IS NOT NULL
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'error', SQLERRM,
            'success', false
        );
END;
$$;


ALTER FUNCTION "public"."fix_user_profile"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fix_user_profile"("p_user_id" "uuid", "p_user_email" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_org_id UUID;
BEGIN
    -- Find user's organization
    SELECT organization_id INTO v_org_id
    FROM users 
    WHERE id = p_user_id;
    
    IF v_org_id IS NULL THEN
        -- Try to find organization through store access
        SELECT s.organization_id INTO v_org_id
        FROM user_store_access usa
        JOIN stores s ON usa.store_id = s.id
        WHERE usa.user_id = p_user_id
        LIMIT 1;
        
        IF v_org_id IS NOT NULL THEN
            -- Update user with found organization
            UPDATE users 
            SET organization_id = v_org_id, updated_at = NOW()
            WHERE id = p_user_id;
        END IF;
    END IF;
    
    RETURN json_build_object(
        'user_id', p_user_id,
        'organization_id', v_org_id,
        'success', v_org_id IS NOT NULL
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'error', SQLERRM,
            'success', false
        );
END;
$$;


ALTER FUNCTION "public"."fix_user_profile"("p_user_id" "uuid", "p_user_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_cds_token"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  timestamp_part TEXT;
  random_part TEXT;
BEGIN
  -- Create timestamp-based token for uniqueness and expiration tracking
  timestamp_part := EXTRACT(EPOCH FROM NOW())::TEXT;
  random_part := encode(gen_random_bytes(16), 'hex');
  
  RETURN 'cds_' || timestamp_part || '_' || random_part;
END;
$$;


ALTER FUNCTION "public"."generate_cds_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_order_number"("store_id_param" "uuid") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    store_prefix TEXT;
    today_date TEXT;
    sequence_num INTEGER;
BEGIN
    -- Get store name first letter or use default
    SELECT COALESCE(UPPER(LEFT(name, 1)), 'S') INTO store_prefix
    FROM stores WHERE id = store_id_param;
    
    -- Get today's date in YYMMDD format
    today_date = TO_CHAR(NOW(), 'YYMMDD');
    
    -- Get next sequence number for today
    SELECT COALESCE(MAX(CAST(RIGHT(order_number, 4) AS INTEGER)), 0) + 1
    INTO sequence_num
    FROM orders
    WHERE store_id = store_id_param
    AND order_number LIKE store_prefix || today_date || '%'
    AND created_at::DATE = CURRENT_DATE;
    
    RETURN store_prefix || today_date || LPAD(sequence_num::TEXT, 4, '0');
END;
$$;


ALTER FUNCTION "public"."generate_order_number"("store_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_order_number"("p_store_id" "uuid", "p_timezone" "text" DEFAULT 'UTC'::"text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_current_date DATE;
  v_next_sequence INTEGER;
  v_order_number TEXT;
BEGIN
  -- Get current date in store's timezone
  v_current_date := (NOW() AT TIME ZONE p_timezone)::DATE;

  -- Insert or update sequence for today, returning the new sequence number
  INSERT INTO order_sequences (store_id, sequence_date, current_sequence)
  VALUES (p_store_id, v_current_date, 1)
  ON CONFLICT (store_id, sequence_date)
  DO UPDATE SET
    current_sequence = order_sequences.current_sequence + 1,
    updated_at = NOW()
  RETURNING current_sequence INTO v_next_sequence;

  -- Format order number as ORD-0001, ORD-0002, etc.
  v_order_number := 'ORD-' || LPAD(v_next_sequence::TEXT, 4, '0');

  RETURN v_order_number;
END;
$$;


ALTER FUNCTION "public"."generate_order_number"("p_store_id" "uuid", "p_timezone" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."generate_order_number"("p_store_id" "uuid", "p_timezone" "text") IS 'Generates next order number for a store with timezone support';



CREATE OR REPLACE FUNCTION "public"."generate_receipt_number"("p_store_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_next BIGINT;
  v_lock_key BIGINT;
BEGIN
  -- Convert store_id to bigint for advisory lock
  v_lock_key := ABS(hashtext(p_store_id::TEXT))::BIGINT;
  
  -- Acquire advisory lock for this store (transaction-level)
  PERFORM pg_advisory_xact_lock(v_lock_key);
  
  -- Insert or update counter atomically using ON CONFLICT
  -- This is the same pattern as your order_sequences table
  INSERT INTO receipt_number_sequences (store_id, current_number)
  VALUES (p_store_id, 1)
  ON CONFLICT (store_id)
  DO UPDATE SET
    current_number = receipt_number_sequences.current_number + 1,
    updated_at = NOW()
  RETURNING current_number INTO v_next;
  
  RETURN v_next::TEXT;
END;
$$;


ALTER FUNCTION "public"."generate_receipt_number"("p_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_session_token"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  token text;
BEGIN
  -- Generate a random token with prefix for easy identification
  token := 'cds_' || encode(gen_random_bytes(32), 'hex');
  RETURN token;
END;
$$;


ALTER FUNCTION "public"."generate_session_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_active_self_order_displays"("p_store_id" "uuid") RETURNS TABLE("id" "uuid", "name" "text", "device_id" "text", "device_name" "text", "display_type" "text", "location" "text", "settings" "jsonb", "last_seen_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sod.id,
        sod.name,
        sod.device_id,
        sod.device_name,
        sod.display_type,
        sod.location,
        sod.settings,
        sod.last_seen_at
    FROM self_order_displays sod
    WHERE sod.store_id = p_store_id 
    AND sod.status = 'active'
    ORDER BY sod.name;
END;
$$;


ALTER FUNCTION "public"."get_active_self_order_displays"("p_store_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" character varying(255) NOT NULL,
    "description" "text",
    "color" character varying(7),
    "sort_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "active_in_bos" boolean,
    "grid_number" integer,
    "translations" "jsonb"
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


COMMENT ON COLUMN "public"."categories"."grid_number" IS 'Display order for categories in POS grid (1-based, per organization)';



CREATE OR REPLACE FUNCTION "public"."get_available_categories"("p_organization_id" "uuid", "p_current_time_utc" time without time zone, "p_current_dow" integer) RETURNS SETOF "public"."categories"
    LANGUAGE "sql" STABLE
    AS $$SELECT
  c.*
FROM public.categories c
WHERE
  c.organization_id = p_organization_id
  AND c.is_active = TRUE
  AND c.active_in_bos = TRUE
  AND (
    -- No availability rows => always available
    NOT EXISTS (
      SELECT 1
      FROM category_availability ca
      WHERE ca.category_id = c.id
    )
    OR EXISTS (
      SELECT 1
      FROM category_availability ca
      WHERE
        ca.category_id = c.id
        -- Day-of-week match (convert both to same type)
        AND (
          ca.available_days IS NULL
          OR cardinality(ca.available_days) = 0
          OR p_current_dow = ANY (ca.available_days::int[])
          OR (p_current_dow = 0 AND 7 = ANY (ca.available_days::int[]))
        )
        -- Time window in UTC (handles normal and overnight windows)
        AND (
          (ca.start_time <= ca.end_time
           AND (p_current_time_utc::time) BETWEEN ca.start_time AND ca.end_time)
          OR
          (ca.start_time > ca.end_time
           AND ((p_current_time_utc::time) >= ca.start_time OR (p_current_time_utc::time) <= ca.end_time))
        )
    )
  )
ORDER BY
  c.sort_order ASC,
  c.name ASC;$$;


ALTER FUNCTION "public"."get_available_categories"("p_organization_id" "uuid", "p_current_time_utc" time without time zone, "p_current_dow" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cds_cart_by_token"("p_token" "text") RETURNS TABLE("cart_token" "text", "items" "jsonb", "totals" "jsonb", "table_number" integer, "dining_option" "text", "call_number" integer, "status" "text", "updated_at" timestamp with time zone, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Validate token
  IF NOT is_cds_token_valid(p_token) THEN
    RAISE EXCEPTION 'Invalid or expired CDS token: %', p_token;
  END IF;

  RETURN QUERY
  SELECT 
    c.token::TEXT,
    c.items,
    c.totals,
    c.table_number,
    c.dining_option::TEXT,
    c.call_number,
    c.status::TEXT,
    c.updated_at,
    c.created_at
  FROM cds_carts c
  WHERE c.token = p_token
  AND c.status = 'active';
END;
$$;


ALTER FUNCTION "public"."get_cds_cart_by_token"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_current_sequence"("p_store_id" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_sequence INTEGER;
  v_target_date DATE;
BEGIN
  -- Use current date if not specified
  v_target_date := COALESCE(p_date, CURRENT_DATE);

  -- Get current sequence for the store and date
  SELECT COALESCE(current_sequence, 0)
  INTO v_sequence
  FROM order_sequences
  WHERE store_id = p_store_id AND sequence_date = v_target_date;

  RETURN COALESCE(v_sequence, 0);
END;
$$;


ALTER FUNCTION "public"."get_current_sequence"("p_store_id" "uuid", "p_date" "date") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_current_sequence"("p_store_id" "uuid", "p_date" "date") IS 'Gets current sequence number for a store on a specific date';



CREATE OR REPLACE FUNCTION "public"."get_organization_business_id"("org_id" "uuid") RETURNS TABLE("business_id" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  -- Make the org_id visible to the RLS policy (GUC is request-local)
  perform set_config('app.org_id', org_id::text, true);

  -- Return only the single column you want to expose
  return query
  select o.business_id
  from public.organizations as o
  where o.id = org_id;            -- o.id is uuid; business_id is text
end;
$$;


ALTER FUNCTION "public"."get_organization_business_id"("org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_restore_status"("p_restore_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    request_record order_restore_requests%ROWTYPE;
BEGIN
    SELECT * INTO request_record 
    FROM order_restore_requests 
    WHERE id = p_restore_request_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Restore request not found'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'restore_request_id', request_record.id,
        'order_id', request_record.order_id,
        'store_id', request_record.store_id,
        'processed', request_record.processed,
        'processed_at', request_record.processed_at,
        'error_message', request_record.error_message,
        'requested_by', request_record.requested_by,
        'requested_at', request_record.requested_at
    );
END;
$$;


ALTER FUNCTION "public"."get_restore_status"("p_restore_request_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_schema_info"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
  DECLARE
    result jsonb;
  BEGIN
    SELECT jsonb_build_object(
      'tables', (
        SELECT jsonb_agg(table_name)
        FROM information_schema.tables
        WHERE table_schema = 'public'
      ),
      'columns', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'table_name', table_name,
            'column_name', column_name,
            'data_type', data_type
          )
        )
        FROM information_schema.columns
        WHERE table_schema = 'public'
      ),
      'policies', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'tablename', tablename,
            'policyname', policyname
          )
        )
        FROM pg_policies
        WHERE schemaname = 'public'
      )
    ) INTO result;

    RETURN result;
  END;
  $$;


ALTER FUNCTION "public"."get_schema_info"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_session_for_cds"("session_id" "uuid") RETURNS TABLE("id" "uuid", "status" "text", "organization_id" "uuid", "store_id" "uuid", "table_number" integer, "is_persistent" boolean, "last_heartbeat_at" timestamp with time zone, "connection_expires_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    s.status,
    s.organization_id,
    s.store_id,
    s.table_number,
    s.is_persistent,
    s.last_heartbeat_at,
    s.connection_expires_at
  FROM cds_sessions s
  WHERE s.id = $1;
END;
$_$;


ALTER FUNCTION "public"."get_session_for_cds"("session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_organization_id"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
  -- First try to get from JWT (for backward compatibility)
  BEGIN
    RETURN COALESCE(
      (current_setting('request.jwt.claims', true)::json->>'organization_id')::uuid,
      (auth.jwt()->>'organization_id')::uuid
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  
  -- Fallback: get organization_id from users table
  IF auth.uid() IS NOT NULL THEN
    RETURN (
      SELECT organization_id 
      FROM public.users 
      WHERE id = auth.uid()
      LIMIT 1
    );
  END IF;
  
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."get_user_organization_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_organizations"("user_uuid" "uuid") RETURNS TABLE("organization_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT 
    CASE 
      WHEN ra.scope_type = 'ORG' THEN ra.scope_id
      WHEN ra.scope_type = 'STORE' THEN s.organization_id
      ELSE NULL
    END as organization_id
  FROM role_assignments ra
  LEFT JOIN stores s ON ra.scope_type = 'STORE' AND ra.scope_id = s.id
  WHERE ra.user_id = user_uuid
  AND organization_id IS NOT NULL;
END;
$$;


ALTER FUNCTION "public"."get_user_organizations"("user_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_stores"("p_user_id" "uuid") RETURNS TABLE("store_id" "uuid", "store_name" "text", "role" "text", "organization_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id AS store_id,
    s.name AS store_name,
    usr.role,
    s.organization_id
  FROM user_store_roles usr
  JOIN stores s ON s.id = usr.store_id
  WHERE usr.user_id = p_user_id
  ORDER BY s.name;
END;
$$;


ALTER FUNCTION "public"."get_user_stores"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."insert_product_at_position"("p_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) RETURNS TABLE("returned_product_id" "uuid", "new_display_order" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- 入力値検証
  IF p_insert_position < 1 THEN
    p_insert_position := 1;
  END IF;

  -- タブと商品の存在確認
  IF NOT EXISTS (
    SELECT 1 FROM product_tab_items pti
    WHERE pti.tab_id = p_tab_id AND pti.product_id = p_product_id
  ) THEN
    RAISE EXCEPTION 'Product not found in specified tab';
  END IF;

  -- 挿入位置以降の商品をシフト
  UPDATE product_tab_items
  SET display_order = display_order + 1
  WHERE tab_id = p_tab_id
    AND display_order >= p_insert_position
    AND product_id != p_product_id;

  -- 対象商品の位置を設定
  UPDATE product_tab_items
  SET display_order = p_insert_position
  WHERE tab_id = p_tab_id AND product_id = p_product_id;

  -- display_orderの正規化（欠番を詰める）
  WITH ordered_products AS (
    SELECT 
      pti.product_id, 
      ROW_NUMBER() OVER (ORDER BY pti.display_order, pti.created_at) as new_order
    FROM product_tab_items pti
    WHERE pti.tab_id = p_tab_id
  )
  UPDATE product_tab_items
  SET display_order = ordered_products.new_order
  FROM ordered_products
  WHERE product_tab_items.product_id = ordered_products.product_id
    AND product_tab_items.tab_id = p_tab_id;

  -- 結果を返却
  RETURN QUERY
  SELECT pti.product_id as returned_product_id, pti.display_order as new_display_order
  FROM product_tab_items pti
  WHERE pti.tab_id = p_tab_id
  ORDER BY pti.display_order;
END;
$$;


ALTER FUNCTION "public"."insert_product_at_position"("p_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_cds_token_valid"("token_input" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
  token_ts NUMERIC;
  current_ts NUMERIC;
BEGIN
  -- Extract timestamp from token format: cds_TIMESTAMP_RANDOM
  IF NOT token_input ~ '^cds_[0-9]+(\.[0-9]+)?_[a-f0-9]+$' THEN
    RETURN FALSE;
  END IF;
  
  -- Extract timestamp part (handle decimal timestamps)
  token_ts := (regexp_split_to_array(token_input, '_'))[2]::NUMERIC;
  current_ts := EXTRACT(EPOCH FROM NOW())::NUMERIC;
  
  -- Check if token is less than 24 hours old
  RETURN (current_ts - token_ts) < (24 * 60 * 60);
END;
$_$;


ALTER FUNCTION "public"."is_cds_token_valid"("token_input" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_owner_or_admin"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN (
        SELECT role IN ('owner', 'admin')
        FROM users
        WHERE id = auth.uid()
    );
END;
$$;


ALTER FUNCTION "public"."is_owner_or_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_display_orders"("p_tab_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  WITH ordered_products AS (
    SELECT 
      pti.product_id, 
      ROW_NUMBER() OVER (ORDER BY pti.display_order, pti.created_at) as new_order
    FROM product_tab_items pti
    WHERE pti.tab_id = p_tab_id
  )
  UPDATE product_tab_items
  SET display_order = ordered_products.new_order
  FROM ordered_products
  WHERE product_tab_items.product_id = ordered_products.product_id
    AND product_tab_items.tab_id = p_tab_id;
END;
$$;


ALTER FUNCTION "public"."normalize_display_orders"("p_tab_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_category_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
  DECLARE
      store_record RECORD;
      payload json;
  BEGIN
      -- シンプルなペイロード：変更があったことだけを通知
      payload := json_build_object(
          'event', 'table_changed',
          'table', 'categories',
          'organization_id', COALESCE(NEW.organization_id, OLD.organization_id)::text,
          'timestamp', extract(epoch from now()) * 1000,
          'requires_reload', true
      );

      -- 組織に属する全店舗に通知
      FOR store_record IN
          SELECT id FROM stores
          WHERE organization_id = COALESCE(NEW.organization_id, OLD.organization_id)
          AND is_active = true
      LOOP
          PERFORM pg_notify('store_' || store_record.id::text, payload::text);
      END LOOP;

      IF TG_OP = 'DELETE' THEN
          RETURN OLD;
      ELSE
          RETURN NEW;
      END IF;
  END;
  $$;


ALTER FUNCTION "public"."notify_category_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_cds_session_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    payload JSONB;
    channel_name TEXT;
    display_id_val TEXT;
    store_id_val TEXT;
BEGIN
    -- Extract key values for both old and new records
    CASE TG_OP
        WHEN 'INSERT' THEN
            display_id_val := NEW.display_id;
            store_id_val := NEW.store_id;
            payload := jsonb_build_object(
                'event', 'INSERT',
                'table', TG_TABLE_NAME,
                'session_id', NEW.id,
                'display_id', NEW.display_id,
                'store_id', NEW.store_id,
                'organization_id', NEW.organization_id,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(NEW)
            );
        WHEN 'UPDATE' THEN
            display_id_val := NEW.display_id;
            store_id_val := NEW.store_id;
            payload := jsonb_build_object(
                'event', 'UPDATE',
                'table', TG_TABLE_NAME,
                'session_id', NEW.id,
                'display_id', NEW.display_id,
                'store_id', NEW.store_id,
                'organization_id', NEW.organization_id,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(NEW)
            );
        WHEN 'DELETE' THEN
            display_id_val := OLD.display_id;
            store_id_val := OLD.store_id;
            payload := jsonb_build_object(
                'event', 'DELETE',
                'table', TG_TABLE_NAME,
                'session_id', OLD.id,
                'display_id', OLD.display_id,
                'store_id', OLD.store_id,
                'organization_id', OLD.organization_id,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(OLD)
            );
    END CASE;

    -- PHASE 2 MIGRATION: Use unified store channel only (matches WebSocket server pattern)
    IF store_id_val IS NOT NULL THEN
        channel_name := 'store_' || regexp_replace(store_id_val, '[^a-zA-Z0-9_]', '', 'g');
    ELSE
        -- Fallback to display-specific channel if no store_id (legacy support)
        channel_name := 'cds_sessions_' || regexp_replace(display_id_val, '[^a-zA-Z0-9_]', '', 'g');
    END IF;
    
    -- Payload size limit (8KB)
    IF length(payload::text) > 8192 THEN
        payload := jsonb_build_object(
            'event', payload->>'event',
            'table', payload->>'table',
            'session_id', payload->>'session_id',
            'display_id', payload->>'display_id',
            'store_id', payload->>'store_id',
            'timestamp', payload->>'timestamp',
            'error', 'payload_too_large'
        );
    END IF;
    
    -- Send notification to unified store channel (single notification only)
    PERFORM pg_notify(channel_name, payload::text);
    
    -- Debug logging (remove in production)
    RAISE NOTICE 'CDS通知: % - Display: % - Session: % - Channel: %', 
        payload->>'event', payload->>'display_id', payload->>'session_id', channel_name;
    
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
EXCEPTION
    WHEN OTHERS THEN
        -- Error logging
        RAISE WARNING 'notify_cds_session_change error: %', SQLERRM;
        RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


ALTER FUNCTION "public"."notify_cds_session_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_cds_session_change_completed_migration"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    payload jsonb;
    store_channel text;
    store_id_val text;
    migration_phase text := 'completed';
BEGIN
    -- Extract store_id safely
    store_id_val := CASE TG_OP 
        WHEN 'DELETE' THEN OLD.store_id::text
        ELSE NEW.store_id::text
    END;

    -- Skip if store_id is NULL (completed migration requires storeId)
    IF store_id_val IS NULL THEN
        RAISE WARNING 'CDS Completed Migration: store_id is NULL, skipping notification';
        RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    -- Build payload based on event type
    CASE TG_OP
        WHEN 'INSERT' THEN 
            payload := jsonb_build_object(
                'event', 'session_inserted',
                'table', TG_TABLE_NAME,
                'session_id', NEW.id,
                'display_id', NEW.display_id,  -- 追加: WebSocketサーバーのCDS検出に必要
                'store_id', NEW.store_id,
                'organization_id', NEW.organization_id,
                'status', NEW.status,
                'table_number', NEW.table_number,
                'migration_phase', migration_phase,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(NEW)
            );
        WHEN 'UPDATE' THEN
            -- Only notify on meaningful changes
            IF (OLD.status IS DISTINCT FROM NEW.status OR
                OLD.cart_data IS DISTINCT FROM NEW.cart_data OR
                OLD.table_number IS DISTINCT FROM NEW.table_number OR
                OLD.is_active IS DISTINCT FROM NEW.is_active) THEN
                
                payload := jsonb_build_object(
                    'event', 'session_updated',
                    'table', TG_TABLE_NAME,
                    'session_id', NEW.id,
                    'display_id', NEW.display_id,  -- 追加: WebSocketサーバーのCDS検出に必要
                    'store_id', NEW.store_id,
                    'organization_id', NEW.organization_id,
                    'old_status', OLD.status,
                    'new_status', NEW.status,
                    'migration_phase', migration_phase,
                    'timestamp', extract(epoch from now())::bigint,
                    'changes', jsonb_build_object(
                        'status', jsonb_build_object('old', OLD.status, 'new', NEW.status),
                        'table_number', jsonb_build_object('old', OLD.table_number, 'new', NEW.table_number),
                        'cart_data_changed', (OLD.cart_data IS DISTINCT FROM NEW.cart_data)
                    ),
                    'record', to_jsonb(NEW)
                );
            ELSE
                RETURN NEW; -- No meaningful changes, skip notification
            END IF;
        WHEN 'DELETE' THEN
            payload := jsonb_build_object(
                'event', 'session_deleted',
                'table', TG_TABLE_NAME,
                'session_id', OLD.id,
                'display_id', OLD.display_id,  -- 追加: WebSocketサーバーのCDS検出に必要
                'store_id', OLD.store_id,
                'organization_id', OLD.organization_id,
                'migration_phase', migration_phase,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(OLD)
            );
    END CASE;

    -- 統一されたストアチャンネル (WebSocketサーバーと整合)
    store_channel := 'store_' || regexp_replace(store_id_val, '[^a-zA-Z0-9_]', '', 'g');
    PERFORM pg_notify(store_channel, payload::text);
    
    RAISE NOTICE 'CDS Completed Migration Notification: % - Store: % - Session: % - Channel: %', 
        payload->>'event', payload->>'store_id', payload->>'session_id', store_channel;
    
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


ALTER FUNCTION "public"."notify_cds_session_change_completed_migration"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_cds_session_change_with_store_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    payload jsonb;
    display_channel text;
    store_channel text;
    display_id_val text;
    store_id_val text;
BEGIN
    -- Extract IDs safely
    display_id_val := CASE TG_OP 
        WHEN 'DELETE' THEN OLD.display_id::text
        ELSE NEW.display_id::text
    END;

    store_id_val := CASE TG_OP 
        WHEN 'DELETE' THEN OLD.store_id::text
        ELSE NEW.store_id::text
    END;

    -- Skip if display_id is NULL
    IF display_id_val IS NULL THEN
        RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    -- Build payload based on event type
    CASE TG_OP
        WHEN 'INSERT' THEN 
            payload := jsonb_build_object(
                'event', 'INSERT',
                'table', TG_TABLE_NAME,
                'session_id', NEW.id,
                'display_id', NEW.display_id,
                'store_id', NEW.store_id,
                'organization_id', NEW.organization_id,
                'status', NEW.status,
                'table_number', NEW.table_number,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(NEW)
            );
        WHEN 'UPDATE' THEN
            payload := jsonb_build_object(
                'event', 'UPDATE',
                'table', TG_TABLE_NAME,
                'session_id', NEW.id,
                'display_id', NEW.display_id,
                'store_id', NEW.store_id,
                'organization_id', NEW.organization_id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(NEW)
            );
        WHEN 'DELETE' THEN
            payload := jsonb_build_object(
                'event', 'DELETE',
                'table', TG_TABLE_NAME,
                'session_id', OLD.id,
                'display_id', OLD.display_id,
                'store_id', OLD.store_id,
                'organization_id', OLD.organization_id,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(OLD)
            );
    END CASE;

    -- Display-specific channel (legacy)
    display_channel := 'cds_sessions_' || regexp_replace(display_id_val, '[^a-zA-Z0-9_]', '', 'g');
    PERFORM pg_notify(display_channel, payload::text);
    
    -- Store-specific channel (new storeId-based)
    IF store_id_val IS NOT NULL THEN
        store_channel := 'cds_store_' || regexp_replace(store_id_val, '[^a-zA-Z0-9_]', '', 'g');
        PERFORM pg_notify(store_channel, payload::text);
        
        RAISE NOTICE 'CDS Store ID Notification: % - Display: % - Store: % - Session: %', 
            payload->>'event', payload->>'display_id', payload->>'store_id', payload->>'session_id';
    END IF;
    
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


ALTER FUNCTION "public"."notify_cds_session_change_with_store_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_kds_order_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    payload jsonb;
    unified_channel_name text;
    store_id_val text;
BEGIN
    -- 安全にstore_idを取得
    store_id_val := CASE TG_OP 
        WHEN 'DELETE' THEN OLD.store_id::text
        ELSE NEW.store_id::text
    END;

    -- store_idがNULLの場合はスキップ
    IF store_id_val IS NULL THEN
        RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    -- イベントタイプに応じてペイロードを構築
    CASE TG_OP
        WHEN 'INSERT' THEN 
            payload := jsonb_build_object(
                'event', 'INSERT',
                'table', TG_TABLE_NAME,
                'order_id', NEW.id,
                'store_id', NEW.store_id,
                'organization_id', NEW.organization_id,
                'kitchen_status', NEW.kitchen_status,
                'status', NEW.status,
                'timestamp', extract(epoch from now())::bigint,
                'created_at', NEW.created_at,
                'record', to_jsonb(NEW)
            );
        WHEN 'UPDATE' THEN
            -- 重要な変更の場合のみ通知
            IF (OLD.kitchen_status IS DISTINCT FROM NEW.kitchen_status OR
                OLD.status IS DISTINCT FROM NEW.status OR
                OLD.kitchen_started_at IS DISTINCT FROM NEW.kitchen_started_at OR
                OLD.kitchen_completed_at IS DISTINCT FROM NEW.kitchen_completed_at) THEN
                
                payload := jsonb_build_object(
                    'event', 'UPDATE',
                    'table', TG_TABLE_NAME,
                    'order_id', NEW.id,
                    'store_id', NEW.store_id,
                    'organization_id', NEW.organization_id,
                    'old_kitchen_status', OLD.kitchen_status,
                    'new_kitchen_status', NEW.kitchen_status,
                    'old_status', OLD.status,
                    'new_status', NEW.status,
                    'timestamp', extract(epoch from now())::bigint,
                    'changes', jsonb_build_object(
                        'kitchen_status', jsonb_build_object('old', OLD.kitchen_status, 'new', NEW.kitchen_status),
                        'status', jsonb_build_object('old', OLD.status, 'new', NEW.status)
                    ),
                    'record', to_jsonb(NEW)
                );
            ELSE
                RETURN NEW; -- 変更がない場合は通知しない
            END IF;
        WHEN 'DELETE' THEN
            payload := jsonb_build_object(
                'event', 'DELETE',
                'table', TG_TABLE_NAME,
                'order_id', OLD.id,
                'store_id', OLD.store_id,
                'organization_id', OLD.organization_id,
                'timestamp', extract(epoch from now())::bigint,
                'record', to_jsonb(OLD)
            );
    END CASE;

    -- PHASE 3: 統一チャネルのみ (CDS共有)
    unified_channel_name := 'store_' || regexp_replace(store_id_val, '[^a-zA-Z0-9_]', '', 'g');
    
    -- ペイロードサイズ制限（8KB）
    IF length(payload::text) > 8192 THEN
        payload := jsonb_build_object(
            'event', payload->>'event',
            'table', payload->>'table',
            'order_id', payload->>'order_id',
            'store_id', payload->>'store_id',
            'timestamp', payload->>'timestamp',
            'error', 'payload_too_large'
        );
    END IF;
    
    -- PHASE 3: 統一チャネルのみに通知送信 (KDS/CDS共有)
    PERFORM pg_notify(unified_channel_name, payload::text);
    
    -- PHASE 3: 完全統一ログ
    RAISE NOTICE '[KDS-MIGRATION-PHASE3] KDS通知: % - 統一チャネル: % - 注文ID: % - 【完全統一移行】', 
        payload->>'event', unified_channel_name, payload->>'order_id';
    
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[KDS-MIGRATION-PHASE3] notify_kds_order_change error: %', SQLERRM;
        RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


ALTER FUNCTION "public"."notify_kds_order_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_product_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
  DECLARE
      store_record RECORD;
      payload json;
  BEGIN
      -- シンプルなペイロード：変更があったことだけを通知
      payload := json_build_object(
          'event', 'table_changed',
          'table', 'products',
          'organization_id', COALESCE(NEW.organization_id, OLD.organization_id)::text,
          'timestamp', extract(epoch from now()) * 1000,
          'requires_reload', true
      );

      -- 組織に属する全店舗に通知
      FOR store_record IN
          SELECT id FROM stores
          WHERE organization_id = COALESCE(NEW.organization_id, OLD.organization_id)
          AND is_active = true
      LOOP
          PERFORM pg_notify('store_' || store_record.id::text, payload::text);
      END LOOP;

      IF TG_OP = 'DELETE' THEN
          RETURN OLD;
      ELSE
          RETURN NEW;
      END IF;
  END;
  $$;


ALTER FUNCTION "public"."notify_product_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_new_user_login"("p_user_id" "uuid", "p_user_email" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  roles_found JSON;
  org_id UUID;
  p_store_id UUID;
  existing_user_org UUID;
  user_exists BOOLEAN := FALSE;
  existing_user_org_id UUID;
BEGIN
  -- Check if user already exists
  SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO user_exists;
  
  -- If user already exists, get their organization_id and return success
  IF user_exists THEN
    SELECT organization_id INTO existing_user_org_id 
    FROM users 
    WHERE id = p_user_id;
    
    RETURN json_build_object(
      'success', true,
      'organization_id', existing_user_org_id,
      'message', 'User already exists - processing complete'
    );
  END IF;

  -- Find user_store_roles for the email
  SELECT json_agg(
    json_build_object(
      'id', usr.id,
      'user_id', usr.user_id,
      'email', usr.email,
      'role', usr.role,
      'store_id', usr.store_id
    )
  ) INTO roles_found
  FROM user_store_roles usr
  WHERE usr.email = p_user_email;
  
  -- If no roles found, return early
  IF roles_found IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No pre-assigned roles found');
  END IF;
  
  -- Get store_id from first role
  SELECT (json_array_elements(roles_found)->>'store_id')::UUID INTO p_store_id;
  
  -- Find organization_id from existing user in same store
  SELECT u.organization_id INTO existing_user_org
  FROM user_store_roles usr
  JOIN users u ON u.id = usr.user_id
  WHERE usr.store_id = p_store_id
  AND usr.user_id IS NOT NULL
  LIMIT 1;
  
  -- If no existing user found, return error
  IF existing_user_org IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No existing users found in store');
  END IF;
  
  -- Create user profile
  INSERT INTO users (id, email, full_name, organization_id, is_active, created_at, updated_at)
  VALUES (
    p_user_id,
    p_user_email,
    split_part(p_user_email, '@', 1),
    existing_user_org,
    true,
    NOW(),
    NOW()
  );
  
  -- Update user_store_roles with user_id
  UPDATE user_store_roles 
  SET user_id = p_user_id, updated_at = NOW()
  WHERE email = p_user_email AND user_id IS NULL;
  
  RETURN json_build_object(
    'success', true, 
    'organization_id', existing_user_org,
    'message', 'User processed successfully'
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false, 
      'error', SQLERRM
    );
END;
$$;


ALTER FUNCTION "public"."process_new_user_login"("p_user_id" "uuid", "p_user_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_order_restore"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    target_order_record orders%ROWTYPE;
    channel_name text;
    payload jsonb;
BEGIN
    -- Get the order to restore
    SELECT * INTO target_order_record 
    FROM orders 
    WHERE id = NEW.order_id;
    
    IF NOT FOUND THEN
        -- Mark request as failed
        UPDATE order_restore_requests 
        SET processed = true, 
            processed_at = now(),
            error_message = 'Order not found'
        WHERE id = NEW.id;
        
        RAISE WARNING 'Order restore failed: Order % not found', NEW.order_id;
        RETURN NEW;
    END IF;
    
    -- Validate store ownership
    IF target_order_record.store_id != NEW.store_id THEN
        -- Mark request as failed
        UPDATE order_restore_requests 
        SET processed = true, 
            processed_at = now(),
            error_message = 'Store mismatch'
        WHERE id = NEW.id;
        
        RAISE WARNING 'Order restore failed: Store mismatch for order %', NEW.order_id;
        RETURN NEW;
    END IF;
    
    -- Only restore completed/ready/served orders (UPDATED TO INCLUDE 'served')
    IF target_order_record.kitchen_status NOT IN ('ready', 'completed', 'served') THEN
        -- Mark request as failed
        UPDATE order_restore_requests 
        SET processed = true, 
            processed_at = now(),
            error_message = 'Order is not in restorable state'
        WHERE id = NEW.id;
        
        RAISE WARNING 'Order restore failed: Order % is in state %', NEW.order_id, target_order_record.kitchen_status;
        RETURN NEW;
    END IF;
    
    BEGIN
        -- Restore the order: Reset to pending status and clear completion timestamps (UPDATED TO CLEAR served_at)
        UPDATE orders 
        SET 
            kitchen_status = 'pending',
            kitchen_completed_at = null,
            served_at = null,
            updated_at = now()
        WHERE id = NEW.order_id;
        
        -- Mark restore request as processed
        UPDATE order_restore_requests 
        SET processed = true, 
            processed_at = now()
        WHERE id = NEW.id;
        
        -- Create notification payload for KDS
        payload := jsonb_build_object(
            'event', 'RESTORE',
            'table', 'orders',
            'order_id', NEW.order_id,
            'store_id', NEW.store_id,
            'organization_id', NEW.organization_id,
            'old_kitchen_status', target_order_record.kitchen_status,
            'new_kitchen_status', 'pending',
            'timestamp', extract(epoch from now())::bigint,
            'restored_by', NEW.requested_by,
            'record', (
                SELECT to_jsonb(o.*) FROM orders o WHERE o.id = NEW.order_id
            )
        );
        
        -- Send notification to store-specific channel
        channel_name := 'kds_orders_' || regexp_replace(NEW.store_id::text, '[^a-zA-Z0-9_]', '', 'g');
        PERFORM pg_notify(channel_name, payload::text);
        
        RAISE NOTICE 'Order % restored successfully by %', NEW.order_id, NEW.requested_by;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Mark request as failed with error
            UPDATE order_restore_requests 
            SET processed = true, 
                processed_at = now(),
                error_message = SQLERRM
            WHERE id = NEW.id;
            
            RAISE WARNING 'Order restore failed for %: %', NEW.order_id, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."process_order_restore"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_order_totals"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_order_id UUID;
  v_order_status TEXT;
  v_subtotal DECIMAL(10,2);
  v_tax_by_rate JSONB;
  v_total_tax DECIMAL(10,2);
  v_total DECIMAL(10,2);
  v_active_count INTEGER;
  v_tax_rate DECIMAL(5,4);
  v_tax_amount DECIMAL(10,2);
  -- NEW: Discount totals variables
  v_manual_discount_total DECIMAL(10,2);
  v_order_coupon_discount_total DECIMAL(10,2);
  v_item_coupon_discount_total DECIMAL(10,2);
  v_total_discount DECIMAL(10,2);
BEGIN
  -- Determine the order_id to process
  IF TG_OP = 'DELETE' THEN
    v_order_id := OLD.order_id;
  ELSE
    v_order_id := COALESCE(NEW.order_id, OLD.order_id);
  END IF;

  -- Check order status - ONLY recalculate for unpaid orders
  SELECT status INTO v_order_status
  FROM orders
  WHERE id = v_order_id;

  -- Skip recalculation for completed/cancelled orders
  IF v_order_status NOT IN ('unpaid', 'pending') THEN
    RAISE NOTICE 'Skipping recalculation for order % with status: %', v_order_id, v_order_status;
    RETURN COALESCE(NEW, OLD);
  END IF;

  RAISE NOTICE 'Recalculating order % (status: %)', v_order_id, v_order_status;

  -- Calculate subtotal and count active items
  -- line_total is tax-inclusive, so we need to calculate tax-exclusive subtotal
  SELECT
    COALESCE(SUM(
      CASE
        WHEN oi.tax_rate > 0 THEN ROUND(oi.line_total / (1 + oi.tax_rate), 2)
        ELSE oi.line_total
      END
    ), 0),
    COUNT(*)
  INTO v_subtotal, v_active_count
  FROM order_items oi
  WHERE oi.order_id = v_order_id
    AND oi.status = 'active';

  -- Calculate tax by rate (as JSONB)
  v_tax_by_rate := '{}'::jsonb;
  v_total_tax := 0;

  FOR v_tax_rate IN
    SELECT DISTINCT tax_rate
    FROM order_items
    WHERE order_id = v_order_id
      AND status = 'active'
      AND tax_rate IS NOT NULL
  LOOP
    -- line_total is tax-inclusive, so extract tax amount correctly
    SELECT COALESCE(SUM(
      ROUND(oi.line_total * oi.tax_rate / (1 + oi.tax_rate), 2)
    ), 0)
    INTO v_tax_amount
    FROM order_items oi
    WHERE oi.order_id = v_order_id
      AND oi.status = 'active'
      AND oi.tax_rate = v_tax_rate;

    v_tax_by_rate := jsonb_set(
      v_tax_by_rate,
      ARRAY[v_tax_rate::text],
      to_jsonb(v_tax_amount)
    );

    v_total_tax := v_total_tax + v_tax_amount;
  END LOOP;

  -- If no tax rates, use empty object
  IF v_tax_by_rate = '{}'::jsonb THEN
    v_tax_by_rate := '{"0": 0}'::jsonb;
  END IF;

  -- Round final total to 2 decimal places
  v_total := ROUND(v_subtotal + v_total_tax, 2);

  -- ========================================
  -- NEW: Calculate discount totals from active order_items
  -- ========================================
  SELECT
    COALESCE(SUM(COALESCE(oi.manual_discount_amount, 0)), 0),
    COALESCE(SUM(COALESCE(oi.order_coupon_discount, 0)), 0),
    COALESCE(SUM(COALESCE(oi.item_coupon_discount, 0)), 0)
  INTO
    v_manual_discount_total,
    v_order_coupon_discount_total,
    v_item_coupon_discount_total
  FROM order_items oi
  WHERE oi.order_id = v_order_id
    AND oi.status = 'active';

  -- Calculate total discount
  v_total_discount := ROUND(
    v_manual_discount_total + v_order_coupon_discount_total + v_item_coupon_discount_total,
    2
  );

  RAISE NOTICE 'Discount totals - Manual: %, OrderCoupon: %, ItemCoupon: %, Total: %',
    v_manual_discount_total, v_order_coupon_discount_total, v_item_coupon_discount_total, v_total_discount;

  -- Update orders table (only for unpaid orders)
  -- Now includes discount totals
  UPDATE orders
  SET
    subtotal = v_subtotal,
    tax_amount = v_tax_by_rate,
    total = v_total,
    -- NEW: Update discount totals
    manual_discount_total = v_manual_discount_total,
    order_coupon_discount_total = v_order_coupon_discount_total,
    item_coupon_discount_total = v_item_coupon_discount_total,
    total_discount = v_total_discount
  WHERE id = v_order_id
    AND status IN ('unpaid', 'pending');

  RAISE NOTICE 'Updated order % - Subtotal: %, Tax: %, Total: %, TotalDiscount: %',
    v_order_id, v_subtotal, v_total_tax, v_total, v_total_discount;

  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."recalculate_order_totals"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recalculate_order_totals"() IS 'Trigger function that recalculates order totals when order_items change.
Calculates: subtotal, tax_amount (by rate), total, and discount totals
(manual_discount_total, order_coupon_discount_total, item_coupon_discount_total, total_discount).
Only fires for orders with status IN (''unpaid'', ''pending'').';



CREATE OR REPLACE FUNCTION "public"."reset_order_sequence"("p_store_id" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_target_date DATE;
BEGIN
  -- Use current date if not specified
  v_target_date := COALESCE(p_date, CURRENT_DATE);

  -- Delete the sequence record for the specified store and date
  DELETE FROM order_sequences
  WHERE store_id = p_store_id AND sequence_date = v_target_date;

  RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."reset_order_sequence"("p_store_id" "uuid", "p_date" "date") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."reset_order_sequence"("p_store_id" "uuid", "p_date" "date") IS 'Resets order sequence for a store on a specific date (admin function)';



CREATE OR REPLACE FUNCTION "public"."restore_order"("p_order_id" "uuid", "p_store_id" "uuid", "p_requested_by" "text" DEFAULT 'system'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    order_record orders%ROWTYPE;
    restore_request_id uuid;
    result jsonb;
BEGIN
    -- Validate order exists
    SELECT * INTO order_record FROM orders WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Order not found',
            'order_id', p_order_id
        );
    END IF;
    
    -- Validate store ownership
    IF order_record.store_id != p_store_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Store mismatch',
            'order_id', p_order_id,
            'expected_store', p_store_id,
            'actual_store', order_record.store_id
        );
    END IF;
    
    -- Check if order is in restorable state (UPDATED TO INCLUDE 'served')
    IF order_record.kitchen_status NOT IN ('ready', 'completed', 'served') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Order is not in restorable state',
            'order_id', p_order_id,
            'current_status', order_record.kitchen_status
        );
    END IF;
    
    -- Create restore request (this will trigger the restoration process)
    INSERT INTO order_restore_requests (
        order_id,
        store_id,
        organization_id,
        requested_by
    ) VALUES (
        p_order_id,
        p_store_id,
        order_record.organization_id,
        p_requested_by
    ) RETURNING id INTO restore_request_id;
    
    -- Wait briefly for processing (trigger is immediate)
    PERFORM pg_sleep(0.1);
    
    -- Check if restoration was successful
    SELECT 
        CASE 
            WHEN processed AND error_message IS NULL THEN
                jsonb_build_object(
                    'success', true,
                    'order_id', order_id,
                    'restore_request_id', id,
                    'processed_at', processed_at,
                    'message', 'Order restored successfully'
                )
            WHEN processed AND error_message IS NOT NULL THEN
                jsonb_build_object(
                    'success', false,
                    'order_id', order_id,
                    'restore_request_id', id,
                    'error', error_message
                )
            ELSE
                jsonb_build_object(
                    'success', false,
                    'order_id', order_id,
                    'restore_request_id', id,
                    'error', 'Restoration still processing'
                )
        END INTO result
    FROM order_restore_requests 
    WHERE id = restore_request_id;
    
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."restore_order"("p_order_id" "uuid", "p_store_id" "uuid", "p_requested_by" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_tos_display"("p_id" "uuid") RETURNS TABLE("id" "uuid", "organization_id" "uuid", "store_id" "uuid")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select id, organization_id, store_id
  from public.tos_displays
  where id = p_id
$$;


ALTER FUNCTION "public"."rpc_get_tos_display"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_category_grid_number"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
  BEGIN
    IF NEW.grid_number IS NULL THEN
      SELECT COALESCE(MAX(grid_number), 0) + 1
      INTO NEW.grid_number
      FROM categories
      WHERE organization_id = NEW.organization_id;
    END IF;
    RETURN NEW;
  END;
  $$;


ALTER FUNCTION "public"."set_category_grid_number"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_product_grid_number"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
  BEGIN
    IF NEW.grid_number IS NULL THEN
      SELECT COALESCE(MAX(grid_number), 0) + 1
      INTO NEW.grid_number
      FROM products
      WHERE organization_id = NEW.organization_id
        AND (
          (category_id = NEW.category_id)
          OR (category_id IS NULL AND NEW.category_id IS NULL)
        );
    END IF;
    RETURN NEW;
  END;
  $$;


ALTER FUNCTION "public"."set_product_grid_number"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."setup_organization_clean"("p_user_id" "uuid", "p_user_email" "text", "p_org_name" "text", "p_org_slug" "text", "p_store_name" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_org_id UUID;
    v_store_id UUID;
BEGIN
    -- ユーザープロファイル作成/更新
    INSERT INTO users (id, email, full_name, role, is_active)
    VALUES (p_user_id, p_user_email, p_user_email, 'owner', true)
    ON CONFLICT (id) DO NOTHING;

    -- 組織作成
    INSERT INTO organizations (id, name, slug, email)
    VALUES (gen_random_uuid(), p_org_name, p_org_slug, p_user_email)
    RETURNING id INTO v_org_id;

    -- ユーザー更新
    UPDATE users SET organization_id = v_org_id WHERE id = p_user_id;

    -- ストア作成
    INSERT INTO stores (id, organization_id, name, is_active)
    VALUES (gen_random_uuid(), v_org_id, p_store_name, true)
    RETURNING id INTO v_store_id;

    -- アクセス権付与 (user_store_roles instead of user_store_access)
    INSERT INTO user_store_roles (user_id, store_id, role, is_active)
    VALUES (p_user_id, v_store_id, 'owner', true);

    RETURN jsonb_build_object('success', true, 'organization_id', v_org_id);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."setup_organization_clean"("p_user_id" "uuid", "p_user_email" "text", "p_org_name" "text", "p_org_slug" "text", "p_store_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."simple_handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Just log that the trigger was called
    RAISE LOG 'New user trigger called for user: %', NEW.id;
    
    -- Try to insert into users table with minimal data
    INSERT INTO public.users (id, email, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        NOW(),
        NOW()
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error details
        RAISE LOG 'Error in user creation: %', SQLERRM;
        RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."simple_handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_new_order_session"("p_display_id" "uuid", "p_store_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  new_session_id UUID;
BEGIN
  -- First cleanup any old sessions for this display
  DELETE FROM customer_display_sessions 
  WHERE display_id = p_display_id;
  
  -- Create fresh session
  INSERT INTO customer_display_sessions (
    display_id,
    store_id,
    active,
    expires_at,
    cart_data
  ) VALUES (
    p_display_id,
    p_store_id,
    true,
    NOW() + INTERVAL '1 hour',
    '{"items": [], "totals": {"subtotal": 0, "tax": 0, "total": 0}}'::jsonb
  ) RETURNING id INTO new_session_id;
  
  RAISE NOTICE 'Started new order session % for display %', new_session_id, p_display_id;
  RETURN new_session_id;
END;
$$;


ALTER FUNCTION "public"."start_new_order_session"("p_display_id" "uuid", "p_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."swap_product_positions"("p_tab_id" "uuid", "product_a_id" "uuid", "product_b_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  order_a INTEGER;
  order_b INTEGER;
BEGIN
  -- 現在のdisplay_orderを取得
  SELECT display_order INTO order_a
  FROM product_tab_items
  WHERE tab_id = p_tab_id AND product_id = product_a_id;

  SELECT display_order INTO order_b
  FROM product_tab_items
  WHERE tab_id = p_tab_id AND product_id = product_b_id;

  IF order_a IS NULL OR order_b IS NULL THEN
    RAISE EXCEPTION 'One or both products not found in specified tab';
  END IF;

  -- display_orderを交換
  UPDATE product_tab_items
  SET display_order = order_b
  WHERE tab_id = p_tab_id AND product_id = product_a_id;

  UPDATE product_tab_items
  SET display_order = order_a
  WHERE tab_id = p_tab_id AND product_id = product_b_id;

  RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."swap_product_positions"("p_tab_id" "uuid", "product_a_id" "uuid", "product_b_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."test_cds_session_triggers"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    test_display_id UUID;
    test_session_id UUID;
    result TEXT := 'CDS Session Trigger Test Results:\n';
BEGIN
    -- Get an existing display_id for testing
    SELECT id INTO test_display_id 
    FROM customer_displays 
    WHERE active = true 
    LIMIT 1;
    
    IF test_display_id IS NULL THEN
        RETURN 'CDS Trigger Test Failed: No active customer_displays found for testing';
    END IF;
    
    -- Test INSERT
    INSERT INTO customer_display_sessions (
        display_id, table_number, call_number, 
        dining_option, active, cart_data, order_totals
    ) VALUES (
        test_display_id, 99, 999,
        'dine_in', true,
        '{"items": [{"name": "Test Item", "price": 10.00}]}'::jsonb,
        '{"subtotal": 10.00, "total": 10.00}'::jsonb
    ) RETURNING id INTO test_session_id;
    result := result || '✅ INSERT trigger fired\n';
    
    -- Test UPDATE
    UPDATE customer_display_sessions 
    SET cart_data = '{"items": [{"name": "Updated Item", "price": 15.00}]}'::jsonb,
        order_totals = '{"subtotal": 15.00, "total": 15.00}'::jsonb
    WHERE id = test_session_id;
    result := result || '✅ UPDATE trigger fired\n';
    
    -- Test DELETE
    DELETE FROM customer_display_sessions WHERE id = test_session_id;
    result := result || '✅ DELETE trigger fired\n';
    
    result := result || '🎉 All CDS session triggers working correctly!';
    
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Cleanup on error
        DELETE FROM customer_display_sessions WHERE id = test_session_id;
        RETURN 'CDS Session Trigger Test Failed: ' || SQLERRM;
END;
$$;


ALTER FUNCTION "public"."test_cds_session_triggers"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."test_cds_session_triggers"() IS 'Test function to verify CDS session trigger functionality';



CREATE OR REPLACE FUNCTION "public"."test_cds_triggers"() RETURNS TABLE("step" "text", "status" "text", "details" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    test_display_id uuid;
    test_session_id uuid;
    store_id_val uuid;
    org_id_val uuid;
BEGIN
    -- Get the valid display ID we know exists
    test_display_id := '395e2dd9-fc7d-46e5-93de-605ad0700fac'::uuid;
    
    -- Get store and org info
    SELECT cd.store_id, cd.organization_id INTO store_id_val, org_id_val
    FROM customer_displays cd WHERE cd.id = test_display_id;
    
    IF store_id_val IS NULL THEN
        RETURN QUERY SELECT 
            'ERROR'::text,
            'FAILED'::text,
            'Display not found or no store_id'::text;
        RETURN;
    END IF;
    
    -- Generate test session ID
    test_session_id := gen_random_uuid();
    
    RETURN QUERY SELECT 
        'SETUP'::text,
        'SUCCESS'::text,
        ('Using display: ' || test_display_id::text || ', store: ' || store_id_val::text)::text;
    
    -- Test 1: INSERT trigger
    INSERT INTO customer_display_sessions (
        id,
        display_id,
        table_number,
        call_number,
        active,
        cart_data,
        created_at
    ) VALUES (
        test_session_id,
        test_display_id,
        1,
        101,
        true,
        '{"items": [], "total": 0}'::jsonb,
        now()
    );
    
    RETURN QUERY SELECT 
        'INSERT'::text,
        'SUCCESS'::text,
        ('Session created: ' || test_session_id::text)::text;
    
    PERFORM pg_sleep(1);
    
    -- Test 2: UPDATE trigger (cart_data change)
    UPDATE customer_display_sessions 
    SET cart_data = '{"items": [{"name": "Test Item", "price": 10.00}], "total": 10.00}'::jsonb
    WHERE id = test_session_id;
    
    RETURN QUERY SELECT 
        'UPDATE'::text,
        'SUCCESS'::text,
        'Cart data updated'::text;
    
    PERFORM pg_sleep(1);
    
    -- Test 3: DELETE trigger
    DELETE FROM customer_display_sessions WHERE id = test_session_id;
    
    RETURN QUERY SELECT 
        'DELETE'::text,
        'SUCCESS'::text,
        'Session deleted'::text;
    
    RETURN QUERY SELECT 
        'COMPLETE'::text,
        'SUCCESS'::text,
        'All CDS trigger tests passed'::text;
END;
$$;


ALTER FUNCTION "public"."test_cds_triggers"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."test_kds_triggers"("test_store_id" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    test_order_uuid uuid;
    test_store_id_to_use text;
BEGIN
    -- Use provided store_id or get first available store
    test_store_id_to_use := COALESCE(test_store_id, (SELECT id::text FROM stores LIMIT 1));
    
    IF test_store_id_to_use IS NULL THEN
        RAISE EXCEPTION 'No store found for testing. Please create a store first.';
    END IF;

    -- Generate test order UUID
    test_order_uuid := gen_random_uuid();
    
    RAISE NOTICE 'Testing KDS triggers with order UUID: % for store: %', test_order_uuid, test_store_id_to_use;
    
    -- Test INSERT trigger
    INSERT INTO orders (
        id, 
        store_id, 
        organization_id,
        status, 
        kitchen_status,
        order_number,
        created_at
    ) VALUES (
        test_order_uuid,
        test_store_id_to_use::uuid,
        (SELECT organization_id FROM stores WHERE id::text = test_store_id_to_use),
        'pending',
        'pending', 
        'KDS-TEST-' || extract(epoch from now())::bigint,
        now()
    );
    
    -- Wait a moment
    PERFORM pg_sleep(1);
    
    -- Test UPDATE trigger
    UPDATE orders 
    SET kitchen_status = 'ready', kitchen_completed_at = now()
    WHERE id = test_order_uuid;
    
    -- Wait a moment
    PERFORM pg_sleep(1);
    
    -- Test DELETE trigger
    DELETE FROM orders WHERE id = test_order_uuid;
    
    RAISE NOTICE 'KDS trigger test completed successfully!';
END;
$$;


ALTER FUNCTION "public"."test_kds_triggers"("test_store_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."test_kds_triggers"("test_store_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("step" "text", "channel_name" "text", "event_type" "text", "order_id" "uuid", "status" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    test_order_id uuid;
    test_store_id_to_use uuid;
    test_org_id uuid;
BEGIN
    test_store_id_to_use := COALESCE(test_store_id, (SELECT id FROM stores LIMIT 1));
    
    IF test_store_id_to_use IS NULL THEN
        RAISE EXCEPTION 'No store found for testing. Please create a store first.';
    END IF;

    SELECT organization_id INTO test_org_id FROM stores WHERE id = test_store_id_to_use;
    test_order_id := gen_random_uuid();
    
    RAISE NOTICE 'Testing KDS Triggers - Store: %, Order: %', test_store_id_to_use, test_order_id;
    
    -- Test INSERT
    INSERT INTO orders (
        id, store_id, organization_id, status, kitchen_status,
        order_number, subtotal, tax_amount, total, created_at
    ) VALUES (
        test_order_id, test_store_id_to_use, test_org_id,
        'pending', 'pending', 
        'TEST-' || extract(epoch from now())::bigint,
        10.00, 1.00, 11.00, now()
    );
    
    RETURN QUERY SELECT 
        'INSERT'::text,
        ('kds_orders_' || regexp_replace(test_store_id_to_use::text, '[^a-zA-Z0-9_]', '', 'g'))::text,
        'INSERT'::text,
        test_order_id,
        'SUCCESS'::text;
    
    -- Clean up
    DELETE FROM orders WHERE id = test_order_id;
    
    RAISE NOTICE 'KDS Trigger Test Complete!';
END;
$$;


ALTER FUNCTION "public"."test_kds_triggers"("test_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."test_order_restore"("test_store_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("step" "text", "status" "text", "order_id" "uuid", "details" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    test_order_id uuid;
    test_store_id_to_use uuid;
    test_org_id uuid;
    restore_result jsonb;
BEGIN
    -- Use provided store_id or get first available store
    test_store_id_to_use := COALESCE(test_store_id, (SELECT id FROM stores LIMIT 1));
    
    IF test_store_id_to_use IS NULL THEN
        RAISE EXCEPTION 'No store found for testing. Please create a store first.';
    END IF;

    -- Get organization ID
    SELECT organization_id INTO test_org_id FROM stores WHERE id = test_store_id_to_use;

    -- Generate test order ID
    test_order_id := gen_random_uuid();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Testing Order Restore System';
    RAISE NOTICE 'Store ID: %', test_store_id_to_use;
    RAISE NOTICE '========================================';
    
    -- Step 1: Create a test order
    INSERT INTO orders (
        id, 
        store_id, 
        organization_id,
        status, 
        kitchen_status,
        order_number,
        subtotal,
        tax_amount,
        total,
        created_at
    ) VALUES (
        test_order_id,
        test_store_id_to_use,
        test_org_id,
        'completed',
        'ready', 
        'RESTORE-TEST-' || extract(epoch from now())::bigint,
        15.00,
        1.50,
        16.50,
        now()
    );
    
    RETURN QUERY SELECT 
        'CREATE_TEST_ORDER'::text,
        'SUCCESS'::text,
        test_order_id,
        'Created test order in ready state'::text;
    
    -- Step 2: Test order restoration
    SELECT restore_order(test_order_id, test_store_id_to_use, 'test_system') INTO restore_result;
    
    IF restore_result->>'success' = 'true' THEN
        RETURN QUERY SELECT 
            'RESTORE_ORDER'::text,
            'SUCCESS'::text,
            test_order_id,
            ('Order restored: ' || restore_result->>'message')::text;
    ELSE
        RETURN QUERY SELECT 
            'RESTORE_ORDER'::text,
            'FAILED'::text,
            test_order_id,
            ('Restore failed: ' || restore_result->>'error')::text;
    END IF;
    
    -- Step 3: Verify order status changed
    PERFORM pg_sleep(0.2);
    
    IF EXISTS (SELECT 1 FROM orders WHERE id = test_order_id AND kitchen_status = 'pending') THEN
        RETURN QUERY SELECT 
            'VERIFY_STATUS'::text,
            'SUCCESS'::text,
            test_order_id,
            'Order status changed to pending'::text;
    ELSE
        RETURN QUERY SELECT 
            'VERIFY_STATUS'::text,
            'FAILED'::text,
            test_order_id,
            'Order status was not changed'::text;
    END IF;
    
    -- Step 4: Cleanup
    DELETE FROM orders WHERE id = test_order_id;
    DELETE FROM order_restore_requests WHERE order_id = test_order_id;
    
    RETURN QUERY SELECT 
        'CLEANUP'::text,
        'SUCCESS'::text,
        test_order_id,
        'Test data cleaned up'::text;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Order Restore System Test Complete!';
    RAISE NOTICE '========================================';
END;
$$;


ALTER FUNCTION "public"."test_order_restore"("test_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_coupons_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_coupons_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_device_categories_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_device_categories_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_inventory_on_order"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Only process completed orders
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Update inventory for each order item
        UPDATE inventory
        SET quantity = inventory.quantity - oi.quantity
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        WHERE inventory.product_id = oi.product_id
        AND inventory.store_id = NEW.store_id
        AND oi.order_id = NEW.id
        AND p.track_inventory = true;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_inventory_on_order"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_order_sequences_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_order_sequences_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_receipt_number_sequences_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_receipt_number_sequences_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_self_order_display_last_seen"("p_device_id" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE self_order_displays 
    SET last_seen_at = NOW()
    WHERE device_id = p_device_id;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count > 0;
END;
$$;


ALTER FUNCTION "public"."update_self_order_display_last_seen"("p_device_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_self_order_display_settings_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_self_order_display_settings_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_self_order_displays_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_self_order_displays_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_session_heartbeat"("p_session_id" "uuid", "p_device_id" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Update session heartbeat
  UPDATE cds_sessions 
  SET last_heartbeat_at = now()
  WHERE id = p_session_id;
  
  -- Update device heartbeat if device_id provided
  IF p_device_id IS NOT NULL THEN
    UPDATE cds_devices 
    SET 
      last_heartbeat_at = now(),
      last_seen_at = now(),
      connection_state = 'connected'
    WHERE device_id = p_device_id;
  END IF;
  
  RETURN true;
END;
$$;


ALTER FUNCTION "public"."update_session_heartbeat"("p_session_id" "uuid", "p_device_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tab_orders"("org_id" "uuid", "tab_order_data" "jsonb") RETURNS TABLE("id" "uuid", "name" "text", "display_order" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- 組織の権限確認
  IF NOT EXISTS (
    SELECT 1 FROM product_tabs 
    WHERE organization_id = org_id 
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'Organization not found or no access';
  END IF;

  -- 一括更新
  UPDATE product_tabs
  SET
    display_order = (tab_data->>'display_order')::INTEGER,
    updated_at = NOW()
  FROM jsonb_array_elements(tab_order_data) AS tab_data
  WHERE product_tabs.id = (tab_data->>'tab_id')::UUID
    AND product_tabs.organization_id = org_id
    AND product_tabs.is_active = true;

  -- 更新結果を返却
  RETURN QUERY
  SELECT pt.id, pt.name, pt.display_order
  FROM product_tabs pt
  WHERE pt.organization_id = org_id
    AND pt.is_active = true
  ORDER BY pt.display_order;
END;
$$;


ALTER FUNCTION "public"."update_tab_orders"("org_id" "uuid", "tab_order_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_table_sessions_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
  BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
  END;
  $$;


ALTER FUNCTION "public"."update_table_sessions_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tos_sessions_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_tos_sessions_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
  BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
  END;
  $$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_cds_cart"("p_token" "text", "p_organization_id" "uuid", "p_store_id" "uuid", "p_items" "jsonb", "p_totals" "jsonb", "p_table_number" integer DEFAULT NULL::integer, "p_dining_option" "text" DEFAULT NULL::"text", "p_call_number" integer DEFAULT NULL::integer) RETURNS TABLE("cart_token" "text", "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Validate token
  IF NOT is_cds_token_valid(p_token) THEN
    RAISE EXCEPTION 'Invalid or expired CDS token: %', p_token;
  END IF;

  -- Upsert cart data
  INSERT INTO cds_carts (
    token,
    organization_id,
    store_id,
    table_number,
    dining_option,
    call_number,
    items,
    totals,
    status,
    updated_at
  ) VALUES (
    p_token,
    p_organization_id,
    p_store_id,
    p_table_number,
    p_dining_option,
    p_call_number,
    p_items,
    p_totals,
    'active',
    NOW()
  )
  ON CONFLICT (token)
  DO UPDATE SET
    items = EXCLUDED.items,
    totals = EXCLUDED.totals,
    table_number = EXCLUDED.table_number,
    dining_option = EXCLUDED.dining_option,
    call_number = EXCLUDED.call_number,
    updated_at = NOW(),
    status = 'active';

  -- Return updated cart info (cast VARCHAR to TEXT)
  RETURN QUERY
  SELECT c.token::TEXT, c.updated_at
  FROM cds_carts c
  WHERE c.token = p_token;
END;
$$;


ALTER FUNCTION "public"."upsert_cds_cart"("p_token" "text", "p_organization_id" "uuid", "p_store_id" "uuid", "p_items" "jsonb", "p_totals" "jsonb", "p_table_number" integer, "p_dining_option" "text", "p_call_number" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_belongs_to_org"("target_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND organization_id = target_org_id
    );
END;
$$;


ALTER FUNCTION "public"."user_belongs_to_org"("target_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_belongs_to_org"("user_uuid" "uuid", "org_uuid" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Check if user has any role in the organization or its stores
  RETURN EXISTS (
    SELECT 1 FROM role_assignments ra
    WHERE ra.user_id = user_uuid
    AND (
      (ra.scope_type = 'ORG' AND ra.scope_id = org_uuid)
      OR (ra.scope_type = 'STORE' AND ra.scope_id IN (
        SELECT id FROM stores WHERE organization_id = org_uuid
      ))
    )
  );
END;
$$;


ALTER FUNCTION "public"."user_belongs_to_org"("user_uuid" "uuid", "org_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_can_access_store"("target_store_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_store_roles 
        WHERE user_id = auth.uid() 
        AND store_id = target_store_id
        AND is_active = true
    ) OR EXISTS (
        SELECT 1 FROM users u
        JOIN stores s ON u.organization_id = s.organization_id
        WHERE u.id = auth.uid() 
        AND s.id = target_store_id
        AND u.role IN ('owner', 'admin')
    );
END;
$$;


ALTER FUNCTION "public"."user_can_access_store"("target_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_has_org_role"("user_uuid" "uuid", "check_role" "text", "org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM role_assignments ra
    WHERE ra.user_id = user_uuid
    AND ra.role = check_role
    AND ra.scope_type = 'ORG'
    AND ra.scope_id = org_id
  );
END;
$$;


ALTER FUNCTION "public"."user_has_org_role"("user_uuid" "uuid", "check_role" "text", "org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_has_store_access"("store_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM user_store_roles usr
        JOIN users u ON usr.user_id = u.id
        WHERE u.id = auth.uid()
        AND usr.store_id = user_has_store_access.store_id
        AND usr.is_active = true
    );
END;
$$;


ALTER FUNCTION "public"."user_has_store_access"("store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_has_store_role"("p_user_id" "uuid", "p_store_id" "uuid", "p_role" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF p_role IS NULL THEN
    -- Check if user has any role for the store
    RETURN EXISTS (
      SELECT 1 FROM user_store_roles
      WHERE user_id = p_user_id
      AND store_id = p_store_id
    );
  ELSE
    -- Check if user has specific role or higher for the store
    RETURN EXISTS (
      SELECT 1 FROM user_store_roles
      WHERE user_id = p_user_id
      AND store_id = p_store_id
      AND (
        role = p_role
        OR (p_role = 'Cashier' AND role IN ('Manager', 'Admin', 'owner'))
        OR (p_role = 'Manager' AND role IN ('Admin', 'owner'))
        OR (p_role = 'Admin' AND role = 'owner')
      )
    );
  END IF;
END;
$$;


ALTER FUNCTION "public"."user_has_store_role"("p_user_id" "uuid", "p_store_id" "uuid", "p_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_in_org"("_org_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.organization_id = _org_id
      AND u.id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."user_in_org"("_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_is_admin"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('owner', 'admin')
    );
END;
$$;


ALTER FUNCTION "public"."user_is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_bos_device"("device_id_param" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$declare
    device_record public.bos_displays%rowtype;
begin
    -- Check if device exists and is active
    select 
        *
    into device_record
    from public.bos_displays
    where id = device_id_param
      and status = 'active';

    if not found then
        return jsonb_build_object(
            'success', false,
            'error', 'Device not found or inactive',
            'device_id', device_id_param
        );
    end if;

    return jsonb_build_object(
        'success', true,
        'device', jsonb_build_object(
            'id', device_record.id,
            'device_name', device_record.device_name,
            'organization_id', device_record.organization_id,
            'status', device_record.status,
            'device_name', device_record.device_name
        )
    );
end;$$;


ALTER FUNCTION "public"."validate_bos_device"("device_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_role_assignment_scope"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Validate that scope_id exists in the appropriate table
  IF NEW.scope_type = 'STORE' THEN
    IF NOT EXISTS (SELECT 1 FROM stores WHERE id = NEW.scope_id) THEN
      RAISE EXCEPTION 'Invalid scope_id: store with id % does not exist', NEW.scope_id;
    END IF;
  ELSIF NEW.scope_type = 'ORG' THEN
    IF NOT EXISTS (SELECT 1 FROM organizations WHERE id = NEW.scope_id) THEN
      RAISE EXCEPTION 'Invalid scope_id: organization with id % does not exist', NEW.scope_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_role_assignment_scope"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "storage"."add_prefixes"("_bucket_id" "text", "_name" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    prefixes text[];
BEGIN
    prefixes := "storage"."get_prefixes"("_name");

    IF array_length(prefixes, 1) > 0 THEN
        INSERT INTO storage.prefixes (name, bucket_id)
        SELECT UNNEST(prefixes) as name, "_bucket_id" ON CONFLICT DO NOTHING;
    END IF;
END;
$$;


ALTER FUNCTION "storage"."add_prefixes"("_bucket_id" "text", "_name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


ALTER FUNCTION "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."delete_leaf_prefixes"("bucket_ids" "text"[], "names" "text"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$$;


ALTER FUNCTION "storage"."delete_leaf_prefixes"("bucket_ids" "text"[], "names" "text"[]) OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."delete_prefix"("_bucket_id" "text", "_name" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Check if we can delete the prefix
    IF EXISTS(
        SELECT FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name") + 1
          AND "prefixes"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    )
    OR EXISTS(
        SELECT FROM "storage"."objects"
        WHERE "objects"."bucket_id" = "_bucket_id"
          AND "storage"."get_level"("objects"."name") = "storage"."get_level"("_name") + 1
          AND "objects"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    ) THEN
    -- There are sub-objects, skip deletion
    RETURN false;
    ELSE
        DELETE FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name")
          AND "prefixes"."name" = "_name";
        RETURN true;
    END IF;
END;
$$;


ALTER FUNCTION "storage"."delete_prefix"("_bucket_id" "text", "_name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."delete_prefix_hierarchy_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    prefix text;
BEGIN
    prefix := "storage"."get_prefix"(OLD."name");

    IF coalesce(prefix, '') != '' THEN
        PERFORM "storage"."delete_prefix"(OLD."bucket_id", prefix);
    END IF;

    RETURN OLD;
END;
$$;


ALTER FUNCTION "storage"."delete_prefix_hierarchy_trigger"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."enforce_bucket_name_length"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


ALTER FUNCTION "storage"."enforce_bucket_name_length"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."extension"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


ALTER FUNCTION "storage"."extension"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."filename"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


ALTER FUNCTION "storage"."filename"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."foldername"("name" "text") RETURNS "text"[]
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


ALTER FUNCTION "storage"."foldername"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_level"("name" "text") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $$
SELECT array_length(string_to_array("name", '/'), 1);
$$;


ALTER FUNCTION "storage"."get_level"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_prefix"("name" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$_$;


ALTER FUNCTION "storage"."get_prefix"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_prefixes"("name" "text") RETURNS "text"[]
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$$;


ALTER FUNCTION "storage"."get_prefixes"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_size_by_bucket"() RETURNS TABLE("size" bigint, "bucket_id" "text")
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


ALTER FUNCTION "storage"."get_size_by_bucket"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "next_key_token" "text" DEFAULT ''::"text", "next_upload_token" "text" DEFAULT ''::"text") RETURNS TABLE("key" "text", "id" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


ALTER FUNCTION "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "next_key_token" "text", "next_upload_token" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."list_objects_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "start_after" "text" DEFAULT ''::"text", "next_token" "text" DEFAULT ''::"text") RETURNS TABLE("name" "text", "id" "uuid", "metadata" "jsonb", "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(name COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                        substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1)))
                    ELSE
                        name
                END AS name, id, metadata, updated_at
            FROM
                storage.objects
            WHERE
                bucket_id = $5 AND
                name ILIKE $1 || ''%'' AND
                CASE
                    WHEN $6 != '''' THEN
                    name COLLATE "C" > $6
                ELSE true END
                AND CASE
                    WHEN $4 != '''' THEN
                        CASE
                            WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                                substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                name COLLATE "C" > $4
                            END
                    ELSE
                        true
                END
            ORDER BY
                name COLLATE "C" ASC) as e order by name COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_token, bucket_id, start_after;
END;
$_$;


ALTER FUNCTION "storage"."list_objects_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "start_after" "text", "next_token" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."lock_top_prefixes"("bucket_ids" "text"[], "names" "text"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_bucket text;
    v_top text;
BEGIN
    FOR v_bucket, v_top IN
        SELECT DISTINCT t.bucket_id,
            split_part(t.name, '/', 1) AS top
        FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        WHERE t.name <> ''
        ORDER BY 1, 2
        LOOP
            PERFORM pg_advisory_xact_lock(hashtextextended(v_bucket || '/' || v_top, 0));
        END LOOP;
END;
$$;


ALTER FUNCTION "storage"."lock_top_prefixes"("bucket_ids" "text"[], "names" "text"[]) OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."objects_delete_cleanup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


ALTER FUNCTION "storage"."objects_delete_cleanup"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."objects_insert_prefix_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    NEW.level := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


ALTER FUNCTION "storage"."objects_insert_prefix_trigger"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."objects_update_cleanup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    -- NEW - OLD (destinations to create prefixes for)
    v_add_bucket_ids text[];
    v_add_names      text[];

    -- OLD - NEW (sources to prune)
    v_src_bucket_ids text[];
    v_src_names      text[];
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    -- 1) Compute NEW−OLD (added paths) and OLD−NEW (moved-away paths)
    WITH added AS (
        SELECT n.bucket_id, n.name
        FROM new_rows n
        WHERE n.name <> '' AND position('/' in n.name) > 0
        EXCEPT
        SELECT o.bucket_id, o.name FROM old_rows o WHERE o.name <> ''
    ),
    moved AS (
         SELECT o.bucket_id, o.name
         FROM old_rows o
         WHERE o.name <> ''
         EXCEPT
         SELECT n.bucket_id, n.name FROM new_rows n WHERE n.name <> ''
    )
    SELECT
        -- arrays for ADDED (dest) in stable order
        COALESCE( (SELECT array_agg(a.bucket_id ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        COALESCE( (SELECT array_agg(a.name      ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        -- arrays for MOVED (src) in stable order
        COALESCE( (SELECT array_agg(m.bucket_id ORDER BY m.bucket_id, m.name) FROM moved m), '{}' ),
        COALESCE( (SELECT array_agg(m.name      ORDER BY m.bucket_id, m.name) FROM moved m), '{}' )
    INTO v_add_bucket_ids, v_add_names, v_src_bucket_ids, v_src_names;

    -- Nothing to do?
    IF (array_length(v_add_bucket_ids, 1) IS NULL) AND (array_length(v_src_bucket_ids, 1) IS NULL) THEN
        RETURN NULL;
    END IF;

    -- 2) Take per-(bucket, top) locks: ALL prefixes in consistent global order to prevent deadlocks
    DECLARE
        v_all_bucket_ids text[];
        v_all_names text[];
    BEGIN
        -- Combine source and destination arrays for consistent lock ordering
        v_all_bucket_ids := COALESCE(v_src_bucket_ids, '{}') || COALESCE(v_add_bucket_ids, '{}');
        v_all_names := COALESCE(v_src_names, '{}') || COALESCE(v_add_names, '{}');

        -- Single lock call ensures consistent global ordering across all transactions
        IF array_length(v_all_bucket_ids, 1) IS NOT NULL THEN
            PERFORM storage.lock_top_prefixes(v_all_bucket_ids, v_all_names);
        END IF;
    END;

    -- 3) Create destination prefixes (NEW−OLD) BEFORE pruning sources
    IF array_length(v_add_bucket_ids, 1) IS NOT NULL THEN
        WITH candidates AS (
            SELECT DISTINCT t.bucket_id, unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(v_add_bucket_ids, v_add_names) AS t(bucket_id, name)
            WHERE name <> ''
        )
        INSERT INTO storage.prefixes (bucket_id, name)
        SELECT c.bucket_id, c.name
        FROM candidates c
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4) Prune source prefixes bottom-up for OLD−NEW
    IF array_length(v_src_bucket_ids, 1) IS NOT NULL THEN
        -- re-entrancy guard so DELETE on prefixes won't recurse
        IF current_setting('storage.gc.prefixes', true) <> '1' THEN
            PERFORM set_config('storage.gc.prefixes', '1', true);
        END IF;

        PERFORM storage.delete_leaf_prefixes(v_src_bucket_ids, v_src_names);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION "storage"."objects_update_cleanup"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."objects_update_level_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Set the new level
        NEW."level" := "storage"."get_level"(NEW."name");
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "storage"."objects_update_level_trigger"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."objects_update_prefix_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    old_prefixes TEXT[];
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Retrieve old prefixes
        old_prefixes := "storage"."get_prefixes"(OLD."name");

        -- Remove old prefixes that are only used by this object
        WITH all_prefixes as (
            SELECT unnest(old_prefixes) as prefix
        ),
        can_delete_prefixes as (
             SELECT prefix
             FROM all_prefixes
             WHERE NOT EXISTS (
                 SELECT 1 FROM "storage"."objects"
                 WHERE "bucket_id" = OLD."bucket_id"
                   AND "name" <> OLD."name"
                   AND "name" LIKE (prefix || '%')
             )
         )
        DELETE FROM "storage"."prefixes" WHERE name IN (SELECT prefix FROM can_delete_prefixes);

        -- Add new prefixes
        PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    END IF;
    -- Set the new level
    NEW."level" := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


ALTER FUNCTION "storage"."objects_update_prefix_trigger"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."operation"() RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


ALTER FUNCTION "storage"."operation"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."prefixes_delete_cleanup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


ALTER FUNCTION "storage"."prefixes_delete_cleanup"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."prefixes_insert_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    RETURN NEW;
END;
$$;


ALTER FUNCTION "storage"."prefixes_insert_trigger"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "offsets" integer DEFAULT 0, "search" "text" DEFAULT ''::"text", "sortcolumn" "text" DEFAULT 'name'::"text", "sortorder" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql"
    AS $$
declare
    can_bypass_rls BOOLEAN;
begin
    SELECT rolbypassrls
    INTO can_bypass_rls
    FROM pg_roles
    WHERE rolname = coalesce(nullif(current_setting('role', true), 'none'), current_user);

    IF can_bypass_rls THEN
        RETURN QUERY SELECT * FROM storage.search_v1_optimised(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    ELSE
        RETURN QUERY SELECT * FROM storage.search_legacy_v1(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    END IF;
end;
$$;


ALTER FUNCTION "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer, "levels" integer, "offsets" integer, "search" "text", "sortcolumn" "text", "sortorder" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_legacy_v1"("prefix" "text", "bucketname" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "offsets" integer DEFAULT 0, "search" "text" DEFAULT ''::"text", "sortcolumn" "text" DEFAULT 'name'::"text", "sortorder" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


ALTER FUNCTION "storage"."search_legacy_v1"("prefix" "text", "bucketname" "text", "limits" integer, "levels" integer, "offsets" integer, "search" "text", "sortcolumn" "text", "sortorder" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_v1_optimised"("prefix" "text", "bucketname" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "offsets" integer DEFAULT 0, "search" "text" DEFAULT ''::"text", "sortcolumn" "text" DEFAULT 'name'::"text", "sortorder" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select (string_to_array(name, ''/''))[level] as name
           from storage.prefixes
             where lower(prefixes.name) like lower($2 || $3) || ''%''
               and bucket_id = $4
               and level = $1
           order by name ' || v_sort_order || '
     )
     (select name,
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[level] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where lower(objects.name) like lower($2 || $3) || ''%''
       and bucket_id = $4
       and level = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


ALTER FUNCTION "storage"."search_v1_optimised"("prefix" "text", "bucketname" "text", "limits" integer, "levels" integer, "offsets" integer, "search" "text", "sortcolumn" "text", "sortorder" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "start_after" "text" DEFAULT ''::"text", "sort_order" "text" DEFAULT 'asc'::"text", "sort_column" "text" DEFAULT 'name'::"text", "sort_column_after" "text" DEFAULT ''::"text") RETURNS TABLE("key" "text", "name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    sort_col text;
    sort_ord text;
    cursor_op text;
    cursor_expr text;
    sort_expr text;
BEGIN
    -- Validate sort_order
    sort_ord := lower(sort_order);
    IF sort_ord NOT IN ('asc', 'desc') THEN
        sort_ord := 'asc';
    END IF;

    -- Determine cursor comparison operator
    IF sort_ord = 'asc' THEN
        cursor_op := '>';
    ELSE
        cursor_op := '<';
    END IF;
    
    sort_col := lower(sort_column);
    -- Validate sort column  
    IF sort_col IN ('updated_at', 'created_at') THEN
        cursor_expr := format(
            '($5 = '''' OR ROW(date_trunc(''milliseconds'', %I), name COLLATE "C") %s ROW(COALESCE(NULLIF($6, '''')::timestamptz, ''epoch''::timestamptz), $5))',
            sort_col, cursor_op
        );
        sort_expr := format(
            'COALESCE(date_trunc(''milliseconds'', %I), ''epoch''::timestamptz) %s, name COLLATE "C" %s',
            sort_col, sort_ord, sort_ord
        );
    ELSE
        cursor_expr := format('($5 = '''' OR name COLLATE "C" %s $5)', cursor_op);
        sort_expr := format('name COLLATE "C" %s', sort_ord);
    END IF;

    RETURN QUERY EXECUTE format(
        $sql$
        SELECT * FROM (
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    NULL::uuid AS id,
                    updated_at,
                    created_at,
                    NULL::timestamptz AS last_accessed_at,
                    NULL::jsonb AS metadata
                FROM storage.prefixes
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
            UNION ALL
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    id,
                    updated_at,
                    created_at,
                    last_accessed_at,
                    metadata
                FROM storage.objects
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
        ) obj
        ORDER BY %s
        LIMIT $3
        $sql$,
        cursor_expr,    -- prefixes WHERE
        sort_expr,      -- prefixes ORDER BY
        cursor_expr,    -- objects WHERE
        sort_expr,      -- objects ORDER BY
        sort_expr       -- final ORDER BY
    )
    USING prefix, bucket_name, limits, levels, start_after, sort_column_after;
END;
$_$;


ALTER FUNCTION "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer, "levels" integer, "start_after" "text", "sort_order" "text", "sort_column" "text", "sort_column_after" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


ALTER FUNCTION "storage"."update_updated_at_column"() OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "auth"."audit_log_entries" (
    "instance_id" "uuid",
    "id" "uuid" NOT NULL,
    "payload" json,
    "created_at" timestamp with time zone,
    "ip_address" character varying(64) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE "auth"."audit_log_entries" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."audit_log_entries" IS 'Auth: Audit trail for user actions.';



CREATE TABLE IF NOT EXISTS "auth"."flow_state" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid",
    "auth_code" "text" NOT NULL,
    "code_challenge_method" "auth"."code_challenge_method" NOT NULL,
    "code_challenge" "text" NOT NULL,
    "provider_type" "text" NOT NULL,
    "provider_access_token" "text",
    "provider_refresh_token" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "authentication_method" "text" NOT NULL,
    "auth_code_issued_at" timestamp with time zone
);


ALTER TABLE "auth"."flow_state" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."flow_state" IS 'stores metadata for pkce logins';



CREATE TABLE IF NOT EXISTS "auth"."identities" (
    "provider_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "identity_data" "jsonb" NOT NULL,
    "provider" "text" NOT NULL,
    "last_sign_in_at" timestamp with time zone,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "email" "text" GENERATED ALWAYS AS ("lower"(("identity_data" ->> 'email'::"text"))) STORED,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "auth"."identities" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."identities" IS 'Auth: Stores identities associated to a user.';



COMMENT ON COLUMN "auth"."identities"."email" IS 'Auth: Email is a generated column that references the optional email property in the identity_data';



CREATE TABLE IF NOT EXISTS "auth"."instances" (
    "id" "uuid" NOT NULL,
    "uuid" "uuid",
    "raw_base_config" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "auth"."instances" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."instances" IS 'Auth: Manages users across multiple sites.';



CREATE TABLE IF NOT EXISTS "auth"."mfa_amr_claims" (
    "session_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL,
    "authentication_method" "text" NOT NULL,
    "id" "uuid" NOT NULL
);


ALTER TABLE "auth"."mfa_amr_claims" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."mfa_amr_claims" IS 'auth: stores authenticator method reference claims for multi factor authentication';



CREATE TABLE IF NOT EXISTS "auth"."mfa_challenges" (
    "id" "uuid" NOT NULL,
    "factor_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "verified_at" timestamp with time zone,
    "ip_address" "inet" NOT NULL,
    "otp_code" "text",
    "web_authn_session_data" "jsonb"
);


ALTER TABLE "auth"."mfa_challenges" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."mfa_challenges" IS 'auth: stores metadata about challenge requests made';



CREATE TABLE IF NOT EXISTS "auth"."mfa_factors" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "friendly_name" "text",
    "factor_type" "auth"."factor_type" NOT NULL,
    "status" "auth"."factor_status" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL,
    "secret" "text",
    "phone" "text",
    "last_challenged_at" timestamp with time zone,
    "web_authn_credential" "jsonb",
    "web_authn_aaguid" "uuid",
    "last_webauthn_challenge_data" "jsonb"
);


ALTER TABLE "auth"."mfa_factors" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."mfa_factors" IS 'auth: stores metadata about factors';



COMMENT ON COLUMN "auth"."mfa_factors"."last_webauthn_challenge_data" IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';



CREATE TABLE IF NOT EXISTS "auth"."oauth_authorizations" (
    "id" "uuid" NOT NULL,
    "authorization_id" "text" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "redirect_uri" "text" NOT NULL,
    "scope" "text" NOT NULL,
    "state" "text",
    "resource" "text",
    "code_challenge" "text",
    "code_challenge_method" "auth"."code_challenge_method",
    "response_type" "auth"."oauth_response_type" DEFAULT 'code'::"auth"."oauth_response_type" NOT NULL,
    "status" "auth"."oauth_authorization_status" DEFAULT 'pending'::"auth"."oauth_authorization_status" NOT NULL,
    "authorization_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '00:03:00'::interval) NOT NULL,
    "approved_at" timestamp with time zone,
    "nonce" "text",
    CONSTRAINT "oauth_authorizations_authorization_code_length" CHECK (("char_length"("authorization_code") <= 255)),
    CONSTRAINT "oauth_authorizations_code_challenge_length" CHECK (("char_length"("code_challenge") <= 128)),
    CONSTRAINT "oauth_authorizations_expires_at_future" CHECK (("expires_at" > "created_at")),
    CONSTRAINT "oauth_authorizations_nonce_length" CHECK (("char_length"("nonce") <= 255)),
    CONSTRAINT "oauth_authorizations_redirect_uri_length" CHECK (("char_length"("redirect_uri") <= 2048)),
    CONSTRAINT "oauth_authorizations_resource_length" CHECK (("char_length"("resource") <= 2048)),
    CONSTRAINT "oauth_authorizations_scope_length" CHECK (("char_length"("scope") <= 4096)),
    CONSTRAINT "oauth_authorizations_state_length" CHECK (("char_length"("state") <= 4096))
);


ALTER TABLE "auth"."oauth_authorizations" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."oauth_clients" (
    "id" "uuid" NOT NULL,
    "client_secret_hash" "text",
    "registration_type" "auth"."oauth_registration_type" NOT NULL,
    "redirect_uris" "text" NOT NULL,
    "grant_types" "text" NOT NULL,
    "client_name" "text",
    "client_uri" "text",
    "logo_uri" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "client_type" "auth"."oauth_client_type" DEFAULT 'confidential'::"auth"."oauth_client_type" NOT NULL,
    CONSTRAINT "oauth_clients_client_name_length" CHECK (("char_length"("client_name") <= 1024)),
    CONSTRAINT "oauth_clients_client_uri_length" CHECK (("char_length"("client_uri") <= 2048)),
    CONSTRAINT "oauth_clients_logo_uri_length" CHECK (("char_length"("logo_uri") <= 2048))
);


ALTER TABLE "auth"."oauth_clients" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."oauth_consents" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "scopes" "text" NOT NULL,
    "granted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revoked_at" timestamp with time zone,
    CONSTRAINT "oauth_consents_revoked_after_granted" CHECK ((("revoked_at" IS NULL) OR ("revoked_at" >= "granted_at"))),
    CONSTRAINT "oauth_consents_scopes_length" CHECK (("char_length"("scopes") <= 2048)),
    CONSTRAINT "oauth_consents_scopes_not_empty" CHECK (("char_length"(TRIM(BOTH FROM "scopes")) > 0))
);


ALTER TABLE "auth"."oauth_consents" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."one_time_tokens" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token_type" "auth"."one_time_token_type" NOT NULL,
    "token_hash" "text" NOT NULL,
    "relates_to" "text" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "one_time_tokens_token_hash_check" CHECK (("char_length"("token_hash") > 0))
);


ALTER TABLE "auth"."one_time_tokens" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."refresh_tokens" (
    "instance_id" "uuid",
    "id" bigint NOT NULL,
    "token" character varying(255),
    "user_id" character varying(255),
    "revoked" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "parent" character varying(255),
    "session_id" "uuid"
);


ALTER TABLE "auth"."refresh_tokens" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."refresh_tokens" IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';



CREATE SEQUENCE IF NOT EXISTS "auth"."refresh_tokens_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "auth"."refresh_tokens_id_seq" OWNER TO "supabase_auth_admin";


ALTER SEQUENCE "auth"."refresh_tokens_id_seq" OWNED BY "auth"."refresh_tokens"."id";



CREATE TABLE IF NOT EXISTS "auth"."saml_providers" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "entity_id" "text" NOT NULL,
    "metadata_xml" "text" NOT NULL,
    "metadata_url" "text",
    "attribute_mapping" "jsonb",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "name_id_format" "text",
    CONSTRAINT "entity_id not empty" CHECK (("char_length"("entity_id") > 0)),
    CONSTRAINT "metadata_url not empty" CHECK ((("metadata_url" = NULL::"text") OR ("char_length"("metadata_url") > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK (("char_length"("metadata_xml") > 0))
);


ALTER TABLE "auth"."saml_providers" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."saml_providers" IS 'Auth: Manages SAML Identity Provider connections.';



CREATE TABLE IF NOT EXISTS "auth"."saml_relay_states" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "request_id" "text" NOT NULL,
    "for_email" "text",
    "redirect_to" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "flow_state_id" "uuid",
    CONSTRAINT "request_id not empty" CHECK (("char_length"("request_id") > 0))
);


ALTER TABLE "auth"."saml_relay_states" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."saml_relay_states" IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';



CREATE TABLE IF NOT EXISTS "auth"."schema_migrations" (
    "version" character varying(255) NOT NULL
);


ALTER TABLE "auth"."schema_migrations" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."schema_migrations" IS 'Auth: Manages updates to the auth system.';



CREATE TABLE IF NOT EXISTS "auth"."sessions" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "factor_id" "uuid",
    "aal" "auth"."aal_level",
    "not_after" timestamp with time zone,
    "refreshed_at" timestamp without time zone,
    "user_agent" "text",
    "ip" "inet",
    "tag" "text",
    "oauth_client_id" "uuid",
    "refresh_token_hmac_key" "text",
    "refresh_token_counter" bigint,
    "scopes" "text",
    CONSTRAINT "sessions_scopes_length" CHECK (("char_length"("scopes") <= 4096))
);


ALTER TABLE "auth"."sessions" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."sessions" IS 'Auth: Stores session data associated to a user.';



COMMENT ON COLUMN "auth"."sessions"."not_after" IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';



COMMENT ON COLUMN "auth"."sessions"."refresh_token_hmac_key" IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';



COMMENT ON COLUMN "auth"."sessions"."refresh_token_counter" IS 'Holds the ID (counter) of the last issued refresh token.';



CREATE TABLE IF NOT EXISTS "auth"."sso_domains" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "domain" "text" NOT NULL,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK (("char_length"("domain") > 0))
);


ALTER TABLE "auth"."sso_domains" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."sso_domains" IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';



CREATE TABLE IF NOT EXISTS "auth"."sso_providers" (
    "id" "uuid" NOT NULL,
    "resource_id" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "disabled" boolean,
    CONSTRAINT "resource_id not empty" CHECK ((("resource_id" = NULL::"text") OR ("char_length"("resource_id") > 0)))
);


ALTER TABLE "auth"."sso_providers" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."sso_providers" IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';



COMMENT ON COLUMN "auth"."sso_providers"."resource_id" IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';



CREATE TABLE IF NOT EXISTS "auth"."users" (
    "instance_id" "uuid",
    "id" "uuid" NOT NULL,
    "aud" character varying(255),
    "role" character varying(255),
    "email" character varying(255),
    "encrypted_password" character varying(255),
    "email_confirmed_at" timestamp with time zone,
    "invited_at" timestamp with time zone,
    "confirmation_token" character varying(255),
    "confirmation_sent_at" timestamp with time zone,
    "recovery_token" character varying(255),
    "recovery_sent_at" timestamp with time zone,
    "email_change_token_new" character varying(255),
    "email_change" character varying(255),
    "email_change_sent_at" timestamp with time zone,
    "last_sign_in_at" timestamp with time zone,
    "raw_app_meta_data" "jsonb",
    "raw_user_meta_data" "jsonb",
    "is_super_admin" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "phone" "text" DEFAULT NULL::character varying,
    "phone_confirmed_at" timestamp with time zone,
    "phone_change" "text" DEFAULT ''::character varying,
    "phone_change_token" character varying(255) DEFAULT ''::character varying,
    "phone_change_sent_at" timestamp with time zone,
    "confirmed_at" timestamp with time zone GENERATED ALWAYS AS (LEAST("email_confirmed_at", "phone_confirmed_at")) STORED,
    "email_change_token_current" character varying(255) DEFAULT ''::character varying,
    "email_change_confirm_status" smallint DEFAULT 0,
    "banned_until" timestamp with time zone,
    "reauthentication_token" character varying(255) DEFAULT ''::character varying,
    "reauthentication_sent_at" timestamp with time zone,
    "is_sso_user" boolean DEFAULT false NOT NULL,
    "deleted_at" timestamp with time zone,
    "is_anonymous" boolean DEFAULT false NOT NULL,
    CONSTRAINT "users_email_change_confirm_status_check" CHECK ((("email_change_confirm_status" >= 0) AND ("email_change_confirm_status" <= 2)))
);


ALTER TABLE "auth"."users" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."users" IS 'Auth: Stores user login data within a secure schema.';



COMMENT ON COLUMN "auth"."users"."is_sso_user" IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';



CREATE TABLE IF NOT EXISTS "public"."account_deletion_audit" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action" character varying(50) NOT NULL,
    "reason" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "account_deletion_audit_action_check" CHECK ((("action")::"text" = ANY ((ARRAY['requested'::character varying, 'cancelled'::character varying, 'anonymized'::character varying, 'completed'::character varying])::"text"[])))
);


ALTER TABLE "public"."account_deletion_audit" OWNER TO "postgres";


COMMENT ON TABLE "public"."account_deletion_audit" IS 'Audit trail for account deletion actions - required for GDPR compliance';



COMMENT ON COLUMN "public"."account_deletion_audit"."action" IS 'Type of action: requested, cancelled, anonymized, or completed';



COMMENT ON COLUMN "public"."account_deletion_audit"."metadata" IS 'Additional metadata about the deletion action';



CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "table_name" character varying(50) NOT NULL,
    "record_id" "uuid" NOT NULL,
    "operation" character varying(10) NOT NULL,
    "old_data" "jsonb",
    "new_data" "jsonb",
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."billing_history" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "subscription_id" "uuid",
    "stripe_invoice_id" "text",
    "amount" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'usd'::"text" NOT NULL,
    "status" "public"."billing_status" DEFAULT 'draft'::"public"."billing_status" NOT NULL,
    "invoice_date" timestamp with time zone NOT NULL,
    "due_date" timestamp with time zone,
    "paid_at" timestamp with time zone,
    "invoice_url" "text",
    "invoice_pdf" "text",
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."billing_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bos_displays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "device_id" "text",
    "device_name" "text",
    "organization_id" "uuid" NOT NULL,
    "store_id" "uuid",
    "status" "text" DEFAULT 'active'::"text",
    "display_type" "text" DEFAULT 'kiosk'::"text",
    "location" "text",
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "last_seen_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "categories" "jsonb",
    "active" boolean,
    CONSTRAINT "self_order_displays_display_type_check" CHECK (("display_type" = ANY (ARRAY['kiosk'::"text", 'tablet'::"text", 'mobile'::"text", 'web'::"text"]))),
    CONSTRAINT "self_order_displays_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'offline'::"text", 'maintenance'::"text"])))
);


ALTER TABLE "public"."bos_displays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cartons" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "carton_barcode" character varying(255),
    "units_per_carton" integer DEFAULT 1 NOT NULL,
    "cost_per_carton" numeric(10,2),
    "supplier" character varying(255),
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "carton_name" character varying(255),
    "carton_sku" character varying(100),
    "dimensions" "jsonb",
    "weight_kg" numeric(10,3),
    "lot_number" character varying(100),
    "expiry_date" "date",
    "notes" "text"
);


ALTER TABLE "public"."cartons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."category_availability" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category_id" "uuid" NOT NULL,
    "available_days" integer[],
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "store_id" "uuid",
    CONSTRAINT "chk_valid_time" CHECK (("start_time" <> "end_time"))
);


ALTER TABLE "public"."category_availability" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."change_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "table_name" character varying(50) NOT NULL,
    "record_id" "uuid" NOT NULL,
    "operation" character varying(10) NOT NULL,
    "data" "jsonb" NOT NULL,
    "device_id" character varying(255),
    "synced_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."change_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."coupons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "description" "text",
    "discount_type" "text" NOT NULL,
    "discount_value" numeric(10,2),
    "minimum_amount" numeric(10,2),
    "max_uses" integer,
    "current_uses" integer DEFAULT 0,
    "expires_at" timestamp with time zone,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "name" "text" NOT NULL,
    "code" character varying(50),
    "type" character varying(20) DEFAULT 'percentage'::character varying,
    "minimum_order_amount" numeric(10,2),
    "maximum_discount_amount" numeric(10,2),
    "applicable_product_ids" "text"[],
    "applicable_category_ids" "text"[],
    "usage_limit" integer,
    "usage_count" integer DEFAULT 0,
    "valid_from" timestamp with time zone,
    "valid_until" timestamp with time zone,
    "status" character varying(20) DEFAULT 'active'::character varying,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "buy_quantity" integer,
    "get_quantity" integer,
    "buy_product_id" "uuid",
    "get_product_id" "uuid",
    "is_open_coupon" boolean DEFAULT false NOT NULL,
    CONSTRAINT "coupons_discount_type_check" CHECK (("discount_type" = ANY (ARRAY['percentage'::"text", 'fixed'::"text"]))),
    CONSTRAINT "coupons_discount_value_check" CHECK (((("is_open_coupon" = true) AND ("discount_value" >= (0)::numeric)) OR (("is_open_coupon" = false) AND ("discount_value" > (0)::numeric)))),
    CONSTRAINT "coupons_status_check" CHECK ((("status")::"text" = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'expired'::character varying, 'used'::character varying])::"text"[]))),
    CONSTRAINT "coupons_type_check" CHECK ((("type")::"text" = ANY ((ARRAY['none'::character varying, 'percentage'::character varying, 'fixed_amount'::character varying, 'free_item'::character varying, 'buy_x_get_y'::character varying, 'bogo'::character varying])::"text"[])))
);


ALTER TABLE "public"."coupons" OWNER TO "postgres";


COMMENT ON COLUMN "public"."coupons"."is_open_coupon" IS 'Flag to indicate if coupon requires discount 
  amount/percentage input at checkout';



COMMENT ON CONSTRAINT "coupons_discount_value_check" ON "public"."coupons" IS 'Discount value must be greater than 0 for regular coupons, can be 0 for open coupons';



CREATE TABLE IF NOT EXISTS "public"."customer_display_sessions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "display_id" "uuid" NOT NULL,
    "table_number" integer,
    "call_number" integer,
    "is_active" boolean DEFAULT true,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '01:00:00'::interval),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "cart_data" "jsonb",
    "order_totals" "jsonb",
    "dining_option" character varying(100),
    "store_id" "uuid",
    "organization_id" "uuid",
    "status" character varying(20) DEFAULT 'active'::character varying,
    CONSTRAINT "customer_display_sessions_status_check" CHECK ((("status")::"text" = ANY ((ARRAY['active'::character varying, 'completed'::character varying, 'expired'::character varying, 'cancelled'::character varying])::"text"[])))
);


ALTER TABLE "public"."customer_display_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_displays" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "store_id" "uuid",
    "name" character varying(255) NOT NULL,
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."customer_displays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "name" "text" NOT NULL,
    "device_type" "text" DEFAULT 'pos'::"text",
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'offline'::"text",
    "store_id" "uuid",
    "ip_address" "text",
    CONSTRAINT "device_settings_device_type_check" CHECK (("device_type" = ANY (ARRAY['pos'::"text", 'display'::"text", 'printer'::"text", 'kitchen'::"text", 'kitchen-display'::"text", 'back-office'::"text", 'customer-display'::"text"]))),
    CONSTRAINT "device_settings_status_check" CHECK (("status" = ANY (ARRAY['online'::"text", 'offline'::"text", 'maintenance'::"text"])))
);


ALTER TABLE "public"."device_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dining_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "active_in_bos" boolean,
    "translations" "jsonb"
);


ALTER TABLE "public"."dining_options" OWNER TO "postgres";


COMMENT ON COLUMN "public"."dining_options"."organization_id" IS 'Organization ID is required for all dining options to ensure proper data isolation';



COMMENT ON COLUMN "public"."dining_options"."active_in_bos" IS 'Boolean parameter for showing the dining options in bos.';



CREATE TABLE IF NOT EXISTS "public"."initialization_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "store_id" "uuid" NOT NULL,
    "store_name" character varying(100) NOT NULL,
    "initialization_type" character varying(20) NOT NULL,
    "products_initialized" integer DEFAULT 0 NOT NULL,
    "initial_quantity" integer DEFAULT 0 NOT NULL,
    "min_quantity" integer DEFAULT 10 NOT NULL,
    "max_quantity" integer DEFAULT 100 NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "initialization_history_initialization_type_check" CHECK ((("initialization_type")::"text" = ANY ((ARRAY['single'::character varying, 'bulk'::character varying])::"text"[])))
);


ALTER TABLE "public"."initialization_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."initialization_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "template_name" character varying(100) NOT NULL,
    "description" "text",
    "initial_quantity" integer DEFAULT 0 NOT NULL,
    "min_quantity" integer DEFAULT 10 NOT NULL,
    "max_quantity" integer DEFAULT 100 NOT NULL,
    "is_default" boolean DEFAULT false,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."initialization_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" integer DEFAULT 0 NOT NULL,
    "min_quantity" integer DEFAULT 0,
    "max_quantity" integer,
    "last_counted_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "inventory_id" "uuid",
    "store_id" "uuid",
    "product_id" "uuid",
    "change_type" "text" NOT NULL,
    "quantity_before" integer NOT NULL,
    "quantity_after" integer NOT NULL,
    "quantity_change" integer NOT NULL,
    "reason" "text",
    "reference_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid",
    CONSTRAINT "inventory_history_change_type_check" CHECK (("change_type" = ANY (ARRAY['adjustment'::"text", 'sale'::"text", 'restock'::"text", 'transfer_in'::"text", 'transfer_out'::"text", 'initial'::"text"]))),
    CONSTRAINT "valid_quantities" CHECK (("quantity_after" = ("quantity_before" + "quantity_change")))
);


ALTER TABLE "public"."inventory_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kitchen_displays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "name" "text" NOT NULL,
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "store_id" "uuid",
    "categories" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."kitchen_displays" OWNER TO "postgres";


COMMENT ON COLUMN "public"."kitchen_displays"."categories" IS 'Array of category IDs that this kitchen display should show orders for';



CREATE TABLE IF NOT EXISTS "public"."modified_order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid",
    "original_item_id" "uuid",
    "product_id" "uuid",
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_price" numeric(10,2) NOT NULL,
    "line_total" numeric(10,2) NOT NULL,
    "modification_type" "public"."modification_type" NOT NULL,
    "reason" "text",
    "modified_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."modified_order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."netvisor_products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "product_code" "text" NOT NULL,
    "product_name" "text" NOT NULL,
    "vat_percentage" numeric NOT NULL,
    "product_type" "text",
    "is_registered" boolean DEFAULT false,
    "registered_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "netvisor_products_product_type_check" CHECK (("product_type" = ANY (ARRAY['sales'::"text", 'discount'::"text"])))
);


ALTER TABLE "public"."netvisor_products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."netvisor_refund_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "transaction_modification_id" "uuid",
    "order_id" "uuid",
    "original_invoice_netvisor_key" "text",
    "credit_note_netvisor_key" "text",
    "refund_amount" numeric(12,2),
    "matched_to_invoice" boolean DEFAULT false,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "error_message" "text",
    "sent_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "netvisor_refund_history_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'success'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."netvisor_refund_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."netvisor_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "partner_id" "text",
    "partner_key" "text",
    "user_id" "text",
    "user_key" "text",
    "organisation_id" "text",
    "sender" "text" DEFAULT 'Sciometa'::"text",
    "customer_identifier" "text",
    "environment" "text" DEFAULT 'test'::"text",
    "host" "text" DEFAULT 'https://isvapi.netvisor.fi'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "netvisor_settings_environment_check" CHECK (("environment" = ANY (ARRAY['test'::"text", 'production'::"text"])))
);


ALTER TABLE "public"."netvisor_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."netvisor_sync_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "store_id" "uuid",
    "sync_date" "date" NOT NULL,
    "gross_amount" numeric,
    "net_amount" numeric,
    "discount_amount" numeric,
    "tax_breakdown" "jsonb",
    "netvisor_invoice_id" "text",
    "invoice_identifier" "text",
    "status" "text",
    "attempt_count" integer DEFAULT 0,
    "is_test" boolean DEFAULT false,
    "request_payload" "jsonb",
    "response_payload" "jsonb",
    "error_message" "text",
    "sent_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "netvisor_sync_history_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'success'::"text", 'failed'::"text", 'retry'::"text"])))
);


ALTER TABLE "public"."netvisor_sync_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."note_templates" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" character varying(255) NOT NULL,
    "text" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "organization_id" "uuid" NOT NULL,
    "active_in_bos" boolean
);


ALTER TABLE "public"."note_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_commits" (
    "client_request_id" "text" NOT NULL,
    "order_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."order_commits" OWNER TO "postgres";


COMMENT ON TABLE "public"."order_commits" IS 'Ensures idempotency for order confirmation requests by storing client request IDs';



CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" numeric(10,3) DEFAULT 1.0 NOT NULL,
    "unit_price" numeric(10,2) NOT NULL,
    "tax_rate" numeric(5,4) DEFAULT 0 NOT NULL,
    "discount_amount" numeric(10,2) DEFAULT 0,
    "line_total" numeric(10,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "comment" "text",
    "unit_price_tax_included" numeric,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'active'::"text",
    "coupon_id" "uuid",
    "manual_discount_amount" numeric(10,2) DEFAULT 0 NOT NULL,
    "order_coupon_discount" numeric(10,2) DEFAULT 0 NOT NULL,
    "item_coupon_discount" numeric(10,2) DEFAULT 0 NOT NULL,
    "display_status" "jsonb",
    "refunded_qty" numeric,
    CONSTRAINT "order_items_quantity_positive" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "order_items_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."order_items" IS 'Order line items. Currency information is managed at organization level via receipt_settings table.';



COMMENT ON COLUMN "public"."order_items"."quantity" IS 'Quantity of the product ordered, supports decimal values for split bills (e.g., 0.5, 1.5)';



COMMENT ON COLUMN "public"."order_items"."updated_at" IS 'Timestamp when the order item was last 
  updated';



COMMENT ON COLUMN "public"."order_items"."status" IS 'Item status: active=active item, 
  cancelled=logically deleted (cancelled)';



COMMENT ON COLUMN "public"."order_items"."coupon_id" IS 'Coupon applied to this specific item (item-level coupon)';



COMMENT ON COLUMN "public"."order_items"."manual_discount_amount" IS 'Manual discount amount set by staff for this item';



COMMENT ON COLUMN "public"."order_items"."order_coupon_discount" IS 'Share of order-level coupon allocated to this item (evenly distributed)';



COMMENT ON COLUMN "public"."order_items"."item_coupon_discount" IS 'Discount amount from item-level coupon';



COMMENT ON COLUMN "public"."order_items"."display_status" IS 'Kitchen Display System (KDS) state management in JSON format.

   Structure (when set):
   - seq: Sequential number for table session orders (integer)
   - status: Current state ("pending" | "ready" | "served")
   - ready_at: Cooking completion timestamp (ISO 8601 | null)
   - served_at: Service completion timestamp (ISO 8601 | null)

   NULL value means:
   - Normal checkout (not using Pay-After-Dining mode)
   - Item should not appear on Kitchen Display

   Example:
   {
     "seq": 1,
     "status": "pending",
     "ready_at": null,
     "served_at": null
   }';



CREATE TABLE IF NOT EXISTS "public"."order_restore_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "store_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "requested_by" "text",
    "requested_at" timestamp with time zone DEFAULT "now"(),
    "processed" boolean DEFAULT false,
    "processed_at" timestamp with time zone,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."order_restore_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_sequences" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "sequence_date" "date" NOT NULL,
    "current_sequence" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."order_sequences" OWNER TO "postgres";


COMMENT ON TABLE "public"."order_sequences" IS 'Manages daily order number sequences for each store';



CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "order_number" character varying(50) NOT NULL,
    "subtotal" numeric(10,2) DEFAULT 0 NOT NULL,
    "total" numeric(10,2) DEFAULT 0 NOT NULL,
    "status" "public"."order_status" DEFAULT 'pending'::"public"."order_status",
    "customer_email" character varying(255),
    "customer_phone" character varying(50),
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "kitchen_status" character varying(20) DEFAULT 'pending'::character varying,
    "kitchen_started_at" timestamp with time zone,
    "kitchen_completed_at" timestamp with time zone,
    "organization_id" "uuid" NOT NULL,
    "call_number" integer,
    "table_number" integer,
    "served_at" timestamp with time zone,
    "discount_amount" "jsonb" DEFAULT '{}'::"jsonb",
    "tax_amount" "jsonb" DEFAULT '{}'::"jsonb",
    "payment_types" "uuid",
    "dining_option" "uuid",
    "exclude_from_monthly_report" boolean DEFAULT false,
    "table_session_id" "uuid",
    "customer_number" integer,
    "coupon_id" "uuid",
    "manual_discount_total" numeric(10,2) DEFAULT 0 NOT NULL,
    "item_coupon_discount_total" numeric(10,2) DEFAULT 0 NOT NULL,
    "total_discount" numeric(10,2) DEFAULT 0 NOT NULL,
    "receipt_number" numeric,
    "order_coupon_discount_total" numeric(10,2) DEFAULT 0 NOT NULL,
    "split_bill_info" "jsonb",
    CONSTRAINT "orders_kitchen_status_check" CHECK ((("kitchen_status")::"text" = ANY (ARRAY[('pending'::character varying)::"text", ('preparing'::character varying)::"text", ('ready'::character varying)::"text", ('served'::character varying)::"text", ('cancelled'::character varying)::"text", ('completed'::character varying)::"text"])))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


COMMENT ON COLUMN "public"."orders"."status" IS '支払い状態: unpaid（未払い）/ paid（支払済）/ refunded（返金済）';



COMMENT ON COLUMN "public"."orders"."discount_amount" IS 'JSON object containing discount breakdown: {"item_discount": amount, "coupon_discount": amount}';



COMMENT ON COLUMN "public"."orders"."tax_amount" IS 'JSON object containing tax breakdown by rate: {"0.08": amount, "0.10": amount}. This replaces the old numeric tax_amount column.';



COMMENT ON COLUMN "public"."orders"."payment_types" IS 'UUID reference to payment_types.id - stores the exact payment type used for this order';



COMMENT ON COLUMN "public"."orders"."dining_option" IS 'UUID reference to dining_options table. NULL represents "No preference" selection.';



COMMENT ON COLUMN "public"."orders"."table_session_id" IS 'Links order to a table session for pay-after-dining';



COMMENT ON COLUMN "public"."orders"."customer_number" IS 'Number of customers for this order';



COMMENT ON COLUMN "public"."orders"."coupon_id" IS 'Coupon applied to the entire order (order-level coupon)';



COMMENT ON COLUMN "public"."orders"."manual_discount_total" IS 'Total of manual discounts across all items';



COMMENT ON COLUMN "public"."orders"."item_coupon_discount_total" IS 'Total of item-level coupon discounts across all items';



COMMENT ON COLUMN "public"."orders"."total_discount" IS 'Grand total of all discounts (manual + order coupon + item coupons)';



COMMENT ON COLUMN "public"."orders"."order_coupon_discount_total" IS 'Order全体に適用されたCouponの割引総額（各アイテムに配分された割引額の合計と一致する）。比例配分方式で計算される。';



COMMENT ON COLUMN "public"."orders"."split_bill_info" IS 'SplitBill情報: { original_order_id?: string } - Savedアイテムがある場合のみ元のOrder IDを保持';



CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" character varying(255) NOT NULL,
    "slug" character varying(100) NOT NULL,
    "email" character varying(255),
    "phone" character varying(50),
    "address" "text",
    "logo_url" "text",
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "business_id" "text",
    "website" "text",
    "bos_kiosk" boolean,
    "lifecycle_status" "public"."organization_lifecycle_status" DEFAULT 'active'::"public"."organization_lifecycle_status" NOT NULL,
    "closed_at" timestamp with time zone,
    "deletion_requested_at" timestamp with time zone,
    "hard_delete_after" timestamp with time zone,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."organizations"."business_id" IS 'Business registration or tax identification number';



COMMENT ON COLUMN "public"."organizations"."bos_kiosk" IS 'Boolean value for those who have paid for BOS service.';



COMMENT ON COLUMN "public"."organizations"."lifecycle_status" IS 'Lifecycle status: active, closing, closed, deleted';



COMMENT ON COLUMN "public"."organizations"."closed_at" IS 'Timestamp when organization was logically closed';



COMMENT ON COLUMN "public"."organizations"."deletion_requested_at" IS 'Timestamp when organization deletion was requested';



COMMENT ON COLUMN "public"."organizations"."hard_delete_after" IS 'Timestamp when organization becomes eligible for hard deletion';



COMMENT ON COLUMN "public"."organizations"."deleted_at" IS 'Timestamp when organization was hard deleted';



CREATE TABLE IF NOT EXISTS "public"."payment_types" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" character varying(255) NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "active_in_bos" boolean,
    "payment_flow" "public"."payment_flow_type",
    "translations" "jsonb"
);


ALTER TABLE "public"."payment_types" OWNER TO "postgres";


COMMENT ON COLUMN "public"."payment_types"."active_in_bos" IS 'Boolean parameter for showing the payment type to be available on the bos';



CREATE TABLE IF NOT EXISTS "public"."pos_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "call_number_enabled" boolean DEFAULT false,
    "call_number_max" integer DEFAULT 20,
    "table_ordering_enabled" boolean DEFAULT false,
    "table_count" integer DEFAULT 20,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "cds_enabled" boolean DEFAULT false,
    "pay_after_dining_enabled" boolean DEFAULT false,
    "auto_print_receipt_enabled" boolean DEFAULT false,
    "pos_layout_mode" character varying(10) DEFAULT 'tabs'::character varying,
    "customer_number_enabled" boolean DEFAULT false,
    "customer_number_max" integer DEFAULT 100,
    "netvisor_enabled" boolean DEFAULT false,
    CONSTRAINT "pos_settings_customer_number_max_check" CHECK ((("customer_number_max" > 0) AND ("customer_number_max" <= 999))),
    CONSTRAINT "pos_settings_pos_layout_mode_check" CHECK ((("pos_layout_mode")::"text" = ANY ((ARRAY['tabs'::character varying, 'grid'::character varying])::"text"[])))
);


ALTER TABLE "public"."pos_settings" OWNER TO "postgres";


COMMENT ON COLUMN "public"."pos_settings"."cds_enabled" IS 'Enable Customer Display System (CDS) for real-time order display to customers';



COMMENT ON COLUMN "public"."pos_settings"."pos_layout_mode" IS 'POS terminal layout mode: tabs (category tabs) or grid (category grid selection)';



COMMENT ON COLUMN "public"."pos_settings"."customer_number_enabled" IS 'Enable customer number input for orders';



COMMENT ON COLUMN "public"."pos_settings"."customer_number_max" IS 'Maximum number of customers allowed per order (1-999)';



CREATE TABLE IF NOT EXISTS "public"."printers" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "organization_id" "uuid" DEFAULT "gen_random_uuid"(),
    "store_id" "uuid" DEFAULT "gen_random_uuid"(),
    "name" "text",
    "ip" "text",
    "active" boolean,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "auto_print_order_enabled" boolean DEFAULT false,
    "printer_categories" "uuid"[] DEFAULT '{}'::"uuid"[]
);


ALTER TABLE "public"."printers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."printers"."auto_print_order_enabled" IS 'Enable automatic printing of orders when received';



COMMENT ON COLUMN "public"."printers"."printer_categories" IS 'Array of category IDs that should be auto-printed by this printer';



ALTER TABLE "public"."printers" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."printers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."product_availabilities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "store_id" "uuid" NOT NULL,
    "status" "public"."product_status",
    "active_in_bos" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."product_availabilities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "category_id" "uuid",
    "name" character varying(255) NOT NULL,
    "description" "text",
    "sku" character varying(100),
    "barcode" character varying(100),
    "price" numeric(10,2) DEFAULT 0 NOT NULL,
    "cost" numeric(10,2) DEFAULT 0,
    "tax_rate" numeric(5,4) DEFAULT 0,
    "image_url" "text",
    "status" "public"."product_status" DEFAULT 'active'::"public"."product_status",
    "track_inventory" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_open_price" boolean DEFAULT false,
    "active_in_bos" boolean DEFAULT true,
    "is_alcoholic" boolean DEFAULT false,
    "grid_number" integer,
    "options" "jsonb",
    "translations" "jsonb"
);


ALTER TABLE "public"."products" OWNER TO "postgres";


COMMENT ON COLUMN "public"."products"."sku" IS 'Stock Keeping Unit - Format: [3-letter category prefix]-[4-digit number] (e.g., FOO-0001)';



COMMENT ON COLUMN "public"."products"."grid_number" IS 'Display order for products in POS grid (1-based, per category within organization)';



CREATE TABLE IF NOT EXISTS "public"."receipt_number_sequences" (
    "store_id" "uuid" NOT NULL,
    "current_number" bigint DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."receipt_number_sequences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."receipt_settings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "header_text" "text",
    "footer_text" "text",
    "show_logo" boolean DEFAULT true,
    "show_address" boolean DEFAULT true,
    "show_phone" boolean DEFAULT true,
    "show_email" boolean DEFAULT true,
    "show_tax_breakdown" boolean DEFAULT true,
    "currency_symbol" character varying(10) DEFAULT '$'::character varying,
    "paper_width" character varying(20) DEFAULT '80mm'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "logo_url" "text",
    "show_barcode" boolean DEFAULT false,
    "show_header" boolean DEFAULT true,
    "show_footer" boolean DEFAULT true,
    "store_id" "uuid",
    "show_organization_name" boolean DEFAULT false,
    "show_store_name" boolean DEFAULT false
);


ALTER TABLE "public"."receipt_settings" OWNER TO "postgres";


COMMENT ON COLUMN "public"."receipt_settings"."show_store_name" IS 'Whether to show store name on receipts';



CREATE TABLE IF NOT EXISTS "public"."server_displays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "name" "text" NOT NULL,
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "store_id" "uuid",
    "categories" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."server_displays" OWNER TO "postgres";


COMMENT ON TABLE "public"."server_displays" IS 'RLS enabled to enforce security policies for server display access';



COMMENT ON COLUMN "public"."server_displays"."categories" IS 'Array of category IDs that this server display should show orders for';



CREATE TABLE IF NOT EXISTS "public"."stores" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" character varying(255) NOT NULL,
    "address" "text",
    "phone" character varying(50),
    "email" character varying(255),
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."stores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscription_plans" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "stripe_price_id" "text",
    "name" "text" NOT NULL,
    "description" "text",
    "price" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'usd'::"text" NOT NULL,
    "interval" "text" DEFAULT 'month'::"text" NOT NULL,
    "interval_count" integer DEFAULT 1 NOT NULL,
    "features" "jsonb" DEFAULT '[]'::"jsonb",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."subscription_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscriptions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "stripe_customer_id" "text",
    "stripe_subscription_id" "text",
    "plan_id" "uuid",
    "status" "public"."subscription_status" DEFAULT 'incomplete'::"public"."subscription_status" NOT NULL,
    "current_period_start" timestamp with time zone,
    "current_period_end" timestamp with time zone,
    "cancel_at" timestamp with time zone,
    "canceled_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "cancel_at_period_end" boolean DEFAULT false
);


ALTER TABLE "public"."subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."table_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "table_number" integer NOT NULL,
    "session_start" timestamp with time zone DEFAULT "now"() NOT NULL,
    "session_end" timestamp with time zone,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "total_amount" numeric(10,2) DEFAULT 0,
    "paid_amount" numeric(10,2) DEFAULT 0,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "customer_count" integer,
    "store_id" "uuid",
    CONSTRAINT "table_sessions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."table_sessions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."table_sessions"."store_id" IS 'Reference to the store where this table session is active';



CREATE TABLE IF NOT EXISTS "public"."tax_settings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" character varying(255) NOT NULL,
    "rate" numeric(5,3) NOT NULL,
    "is_default" boolean DEFAULT false,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tax_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tos_displays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "device_name" "text",
    "organization_id" "uuid" NOT NULL,
    "store_id" "uuid",
    "status" "text" DEFAULT 'active'::"text",
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "last_seen_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "tos_displays_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'offline'::"text"])))
);


ALTER TABLE "public"."tos_displays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tos_sessions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "session_qr_code" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "table_number" integer,
    "customer_count" integer,
    "dining_option_id" "uuid",
    "active" boolean DEFAULT true,
    "expires_at" timestamp with time zone,
    "started_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tos_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transaction_modifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "order_id" "uuid",
    "modification_type" "public"."modification_type" NOT NULL,
    "status" "public"."modification_status" DEFAULT 'pending'::"public"."modification_status",
    "amount" numeric(10,2),
    "quantity" integer,
    "reason" "text",
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "requested_by" "uuid",
    "approved_by" "uuid",
    "processed_by" "uuid",
    "requested_at" timestamp with time zone DEFAULT "now"(),
    "approved_at" timestamp with time zone,
    "processed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."transaction_modifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_store_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "store_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "phone" "text",
    "email" "text",
    "is_active" boolean DEFAULT true,
    "full_name" "text",
    CONSTRAINT "user_or_email_required" CHECK ((("user_id" IS NOT NULL) OR ("email" IS NOT NULL))),
    CONSTRAINT "user_store_roles_role_check" CHECK (("role" = ANY (ARRAY['owner'::"text", 'admin'::"text", 'manager'::"text", 'cashier'::"text"])))
);


ALTER TABLE "public"."user_store_roles" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_store_roles" IS 'User-store role assignments. RLS policies simplified to avoid infinite recursion. 
   Uses safe_* policies that do not self-reference the table.';



COMMENT ON COLUMN "public"."user_store_roles"."phone" IS 'Store-specific phone number for the user (overrides user table phone)';



COMMENT ON COLUMN "public"."user_store_roles"."email" IS 'Email address for pre-invitation records where user_id is NULL';



COMMENT ON COLUMN "public"."user_store_roles"."is_active" IS 'Soft delete flag - false means role is deactivated but preserved for history';



CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "organization_id" "uuid",
    "email" character varying(255) NOT NULL,
    "full_name" character varying(255),
    "avatar_url" "text",
    "phone" character varying(50),
    "is_active" boolean DEFAULT true,
    "last_login_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "role" character varying(20) DEFAULT 'user'::character varying,
    "deletion_requested_at" timestamp with time zone,
    "deletion_scheduled_at" timestamp with time zone,
    "deletion_reason" "text",
    "is_deleted" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "anonymized_at" timestamp with time zone
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."deletion_requested_at" IS 'Timestamp when user requested account deletion';



COMMENT ON COLUMN "public"."users"."deletion_scheduled_at" IS 'Timestamp when account deletion will be executed (30 days after request)';



COMMENT ON COLUMN "public"."users"."deletion_reason" IS 'Optional reason provided by user for account deletion';



COMMENT ON COLUMN "public"."users"."is_deleted" IS 'Soft delete flag - true when account is marked as deleted';



COMMENT ON COLUMN "public"."users"."deleted_at" IS 'Timestamp when account was soft deleted';



COMMENT ON COLUMN "public"."users"."anonymized_at" IS 'Timestamp when user PII was anonymized';



CREATE TABLE IF NOT EXISTS "storage"."buckets" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "public" boolean DEFAULT false,
    "avif_autodetection" boolean DEFAULT false,
    "file_size_limit" bigint,
    "allowed_mime_types" "text"[],
    "owner_id" "text",
    "type" "storage"."buckettype" DEFAULT 'STANDARD'::"storage"."buckettype" NOT NULL
);


ALTER TABLE "storage"."buckets" OWNER TO "supabase_storage_admin";


COMMENT ON COLUMN "storage"."buckets"."owner" IS 'Field is deprecated, use owner_id instead';



CREATE TABLE IF NOT EXISTS "storage"."buckets_analytics" (
    "name" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'ANALYTICS'::"storage"."buckettype" NOT NULL,
    "format" "text" DEFAULT 'ICEBERG'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "storage"."buckets_analytics" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."buckets_vectors" (
    "id" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'VECTOR'::"storage"."buckettype" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."buckets_vectors" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."migrations" (
    "id" integer NOT NULL,
    "name" character varying(100) NOT NULL,
    "hash" character varying(40) NOT NULL,
    "executed_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "storage"."migrations" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."objects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bucket_id" "text",
    "name" "text",
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_accessed_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb",
    "path_tokens" "text"[] GENERATED ALWAYS AS ("string_to_array"("name", '/'::"text")) STORED,
    "version" "text",
    "owner_id" "text",
    "user_metadata" "jsonb",
    "level" integer
);


ALTER TABLE "storage"."objects" OWNER TO "supabase_storage_admin";


COMMENT ON COLUMN "storage"."objects"."owner" IS 'Field is deprecated, use owner_id instead';



CREATE TABLE IF NOT EXISTS "storage"."prefixes" (
    "bucket_id" "text" NOT NULL,
    "name" "text" NOT NULL COLLATE "pg_catalog"."C",
    "level" integer GENERATED ALWAYS AS ("storage"."get_level"("name")) STORED NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "storage"."prefixes" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads" (
    "id" "text" NOT NULL,
    "in_progress_size" bigint DEFAULT 0 NOT NULL,
    "upload_signature" "text" NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "version" "text" NOT NULL,
    "owner_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_metadata" "jsonb"
);


ALTER TABLE "storage"."s3_multipart_uploads" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads_parts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "upload_id" "text" NOT NULL,
    "size" bigint DEFAULT 0 NOT NULL,
    "part_number" integer NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "etag" "text" NOT NULL,
    "owner_id" "text",
    "version" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."s3_multipart_uploads_parts" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."vector_indexes" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL COLLATE "pg_catalog"."C",
    "bucket_id" "text" NOT NULL,
    "data_type" "text" NOT NULL,
    "dimension" integer NOT NULL,
    "distance_metric" "text" NOT NULL,
    "metadata_configuration" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."vector_indexes" OWNER TO "supabase_storage_admin";


ALTER TABLE ONLY "auth"."refresh_tokens" ALTER COLUMN "id" SET DEFAULT "nextval"('"auth"."refresh_tokens_id_seq"'::"regclass");



ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "amr_id_pk" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."audit_log_entries"
    ADD CONSTRAINT "audit_log_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."flow_state"
    ADD CONSTRAINT "flow_state_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_provider_id_provider_unique" UNIQUE ("provider_id", "provider");



ALTER TABLE ONLY "auth"."instances"
    ADD CONSTRAINT "instances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "mfa_amr_claims_session_id_authentication_method_pkey" UNIQUE ("session_id", "authentication_method");



ALTER TABLE ONLY "auth"."mfa_challenges"
    ADD CONSTRAINT "mfa_challenges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_last_challenged_at_key" UNIQUE ("last_challenged_at");



ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_authorization_code_key" UNIQUE ("authorization_code");



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_authorization_id_key" UNIQUE ("authorization_id");



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_clients"
    ADD CONSTRAINT "oauth_clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_user_client_unique" UNIQUE ("user_id", "client_id");



ALTER TABLE ONLY "auth"."one_time_tokens"
    ADD CONSTRAINT "one_time_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_token_unique" UNIQUE ("token");



ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_entity_id_key" UNIQUE ("entity_id");



ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."schema_migrations"
    ADD CONSTRAINT "schema_migrations_pkey" PRIMARY KEY ("version");



ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."sso_domains"
    ADD CONSTRAINT "sso_domains_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."sso_providers"
    ADD CONSTRAINT "sso_providers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."users"
    ADD CONSTRAINT "users_phone_key" UNIQUE ("phone");



ALTER TABLE ONLY "auth"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."account_deletion_audit"
    ADD CONSTRAINT "account_deletion_audit_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."billing_history"
    ADD CONSTRAINT "billing_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cartons"
    ADD CONSTRAINT "cartons_organization_id_carton_barcode_key" UNIQUE ("organization_id", "carton_barcode");



ALTER TABLE ONLY "public"."cartons"
    ADD CONSTRAINT "cartons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."category_availability"
    ADD CONSTRAINT "category_availability_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."change_logs"
    ADD CONSTRAINT "change_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."coupons"
    ADD CONSTRAINT "coupons_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."coupons"
    ADD CONSTRAINT "coupons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_display_sessions"
    ADD CONSTRAINT "customer_display_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_displays"
    ADD CONSTRAINT "customer_displays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_settings"
    ADD CONSTRAINT "device_settings_organization_id_name_key" UNIQUE ("organization_id", "name");



ALTER TABLE ONLY "public"."device_settings"
    ADD CONSTRAINT "device_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dining_options"
    ADD CONSTRAINT "dining_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."initialization_history"
    ADD CONSTRAINT "initialization_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."initialization_templates"
    ADD CONSTRAINT "initialization_templates_organization_id_template_name_key" UNIQUE ("organization_id", "template_name");



ALTER TABLE ONLY "public"."initialization_templates"
    ADD CONSTRAINT "initialization_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_history"
    ADD CONSTRAINT "inventory_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory"
    ADD CONSTRAINT "inventory_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory"
    ADD CONSTRAINT "inventory_store_id_product_id_key" UNIQUE ("store_id", "product_id");



ALTER TABLE ONLY "public"."kitchen_displays"
    ADD CONSTRAINT "kitchen_displays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."modified_order_items"
    ADD CONSTRAINT "modified_order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."netvisor_products"
    ADD CONSTRAINT "netvisor_products_organization_id_product_code_key" UNIQUE ("organization_id", "product_code");



ALTER TABLE ONLY "public"."netvisor_products"
    ADD CONSTRAINT "netvisor_products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."netvisor_refund_history"
    ADD CONSTRAINT "netvisor_refund_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."netvisor_settings"
    ADD CONSTRAINT "netvisor_settings_organization_id_key" UNIQUE ("organization_id");



ALTER TABLE ONLY "public"."netvisor_settings"
    ADD CONSTRAINT "netvisor_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."netvisor_sync_history"
    ADD CONSTRAINT "netvisor_sync_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."note_templates"
    ADD CONSTRAINT "note_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_commits"
    ADD CONSTRAINT "order_commits_pkey" PRIMARY KEY ("client_request_id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_restore_requests"
    ADD CONSTRAINT "order_restore_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_sequences"
    ADD CONSTRAINT "order_sequences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_sequences"
    ADD CONSTRAINT "order_sequences_store_id_sequence_date_key" UNIQUE ("store_id", "sequence_date");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_store_receipt_number_unique" UNIQUE ("store_id", "receipt_number");



COMMENT ON CONSTRAINT "orders_store_receipt_number_unique" ON "public"."orders" IS 'Ensures receipt numbers are unique per store. Each store maintains its own receipt number sequence.';



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."payment_types"
    ADD CONSTRAINT "payment_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pos_settings"
    ADD CONSTRAINT "pos_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."printers"
    ADD CONSTRAINT "printers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_availabilities"
    ADD CONSTRAINT "product_availabilities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_availabilities"
    ADD CONSTRAINT "product_availabilities_product_store_key" UNIQUE ("product_id", "store_id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."receipt_number_sequences"
    ADD CONSTRAINT "receipt_number_sequences_pkey" PRIMARY KEY ("store_id");



ALTER TABLE ONLY "public"."receipt_settings"
    ADD CONSTRAINT "receipt_settings_organization_id_key" UNIQUE ("organization_id");



ALTER TABLE ONLY "public"."receipt_settings"
    ADD CONSTRAINT "receipt_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bos_displays"
    ADD CONSTRAINT "self_order_displays_device_id_key" UNIQUE ("device_id");



ALTER TABLE ONLY "public"."bos_displays"
    ADD CONSTRAINT "self_order_displays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."server_displays"
    ADD CONSTRAINT "server_displays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscription_plans"
    ADD CONSTRAINT "subscription_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscription_plans"
    ADD CONSTRAINT "subscription_plans_stripe_price_id_key" UNIQUE ("stripe_price_id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_stripe_subscription_id_key" UNIQUE ("stripe_subscription_id");



ALTER TABLE ONLY "public"."table_sessions"
    ADD CONSTRAINT "table_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tax_settings"
    ADD CONSTRAINT "tax_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tos_displays"
    ADD CONSTRAINT "tos_displays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tos_sessions"
    ADD CONSTRAINT "tos_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tos_sessions"
    ADD CONSTRAINT "tos_sessions_session_qr_code_key" UNIQUE ("session_qr_code");



ALTER TABLE ONLY "public"."transaction_modifications"
    ADD CONSTRAINT "transaction_modifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_store_roles"
    ADD CONSTRAINT "user_store_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets_analytics"
    ADD CONSTRAINT "buckets_analytics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets"
    ADD CONSTRAINT "buckets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets_vectors"
    ADD CONSTRAINT "buckets_vectors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."prefixes"
    ADD CONSTRAINT "prefixes_pkey" PRIMARY KEY ("bucket_id", "level", "name");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_pkey" PRIMARY KEY ("id");



CREATE INDEX "audit_logs_instance_id_idx" ON "auth"."audit_log_entries" USING "btree" ("instance_id");



CREATE UNIQUE INDEX "confirmation_token_idx" ON "auth"."users" USING "btree" ("confirmation_token") WHERE (("confirmation_token")::"text" !~ '^[0-9 ]*$'::"text");



CREATE UNIQUE INDEX "email_change_token_current_idx" ON "auth"."users" USING "btree" ("email_change_token_current") WHERE (("email_change_token_current")::"text" !~ '^[0-9 ]*$'::"text");



CREATE UNIQUE INDEX "email_change_token_new_idx" ON "auth"."users" USING "btree" ("email_change_token_new") WHERE (("email_change_token_new")::"text" !~ '^[0-9 ]*$'::"text");



CREATE INDEX "factor_id_created_at_idx" ON "auth"."mfa_factors" USING "btree" ("user_id", "created_at");



CREATE INDEX "flow_state_created_at_idx" ON "auth"."flow_state" USING "btree" ("created_at" DESC);



CREATE INDEX "identities_email_idx" ON "auth"."identities" USING "btree" ("email" "text_pattern_ops");



COMMENT ON INDEX "auth"."identities_email_idx" IS 'Auth: Ensures indexed queries on the email column';



CREATE INDEX "identities_user_id_idx" ON "auth"."identities" USING "btree" ("user_id");



CREATE INDEX "idx_auth_code" ON "auth"."flow_state" USING "btree" ("auth_code");



CREATE INDEX "idx_user_id_auth_method" ON "auth"."flow_state" USING "btree" ("user_id", "authentication_method");



CREATE INDEX "mfa_challenge_created_at_idx" ON "auth"."mfa_challenges" USING "btree" ("created_at" DESC);



CREATE UNIQUE INDEX "mfa_factors_user_friendly_name_unique" ON "auth"."mfa_factors" USING "btree" ("friendly_name", "user_id") WHERE (TRIM(BOTH FROM "friendly_name") <> ''::"text");



CREATE INDEX "mfa_factors_user_id_idx" ON "auth"."mfa_factors" USING "btree" ("user_id");



CREATE INDEX "oauth_auth_pending_exp_idx" ON "auth"."oauth_authorizations" USING "btree" ("expires_at") WHERE ("status" = 'pending'::"auth"."oauth_authorization_status");



CREATE INDEX "oauth_clients_deleted_at_idx" ON "auth"."oauth_clients" USING "btree" ("deleted_at");



CREATE INDEX "oauth_consents_active_client_idx" ON "auth"."oauth_consents" USING "btree" ("client_id") WHERE ("revoked_at" IS NULL);



CREATE INDEX "oauth_consents_active_user_client_idx" ON "auth"."oauth_consents" USING "btree" ("user_id", "client_id") WHERE ("revoked_at" IS NULL);



CREATE INDEX "oauth_consents_user_order_idx" ON "auth"."oauth_consents" USING "btree" ("user_id", "granted_at" DESC);



CREATE INDEX "one_time_tokens_relates_to_hash_idx" ON "auth"."one_time_tokens" USING "hash" ("relates_to");



CREATE INDEX "one_time_tokens_token_hash_hash_idx" ON "auth"."one_time_tokens" USING "hash" ("token_hash");



CREATE UNIQUE INDEX "one_time_tokens_user_id_token_type_key" ON "auth"."one_time_tokens" USING "btree" ("user_id", "token_type");



CREATE UNIQUE INDEX "reauthentication_token_idx" ON "auth"."users" USING "btree" ("reauthentication_token") WHERE (("reauthentication_token")::"text" !~ '^[0-9 ]*$'::"text");



CREATE UNIQUE INDEX "recovery_token_idx" ON "auth"."users" USING "btree" ("recovery_token") WHERE (("recovery_token")::"text" !~ '^[0-9 ]*$'::"text");



CREATE INDEX "refresh_tokens_instance_id_idx" ON "auth"."refresh_tokens" USING "btree" ("instance_id");



CREATE INDEX "refresh_tokens_instance_id_user_id_idx" ON "auth"."refresh_tokens" USING "btree" ("instance_id", "user_id");



CREATE INDEX "refresh_tokens_parent_idx" ON "auth"."refresh_tokens" USING "btree" ("parent");



CREATE INDEX "refresh_tokens_session_id_revoked_idx" ON "auth"."refresh_tokens" USING "btree" ("session_id", "revoked");



CREATE INDEX "refresh_tokens_updated_at_idx" ON "auth"."refresh_tokens" USING "btree" ("updated_at" DESC);



CREATE INDEX "saml_providers_sso_provider_id_idx" ON "auth"."saml_providers" USING "btree" ("sso_provider_id");



CREATE INDEX "saml_relay_states_created_at_idx" ON "auth"."saml_relay_states" USING "btree" ("created_at" DESC);



CREATE INDEX "saml_relay_states_for_email_idx" ON "auth"."saml_relay_states" USING "btree" ("for_email");



CREATE INDEX "saml_relay_states_sso_provider_id_idx" ON "auth"."saml_relay_states" USING "btree" ("sso_provider_id");



CREATE INDEX "sessions_not_after_idx" ON "auth"."sessions" USING "btree" ("not_after" DESC);



CREATE INDEX "sessions_oauth_client_id_idx" ON "auth"."sessions" USING "btree" ("oauth_client_id");



CREATE INDEX "sessions_user_id_idx" ON "auth"."sessions" USING "btree" ("user_id");



CREATE UNIQUE INDEX "sso_domains_domain_idx" ON "auth"."sso_domains" USING "btree" ("lower"("domain"));



CREATE INDEX "sso_domains_sso_provider_id_idx" ON "auth"."sso_domains" USING "btree" ("sso_provider_id");



CREATE UNIQUE INDEX "sso_providers_resource_id_idx" ON "auth"."sso_providers" USING "btree" ("lower"("resource_id"));



CREATE INDEX "sso_providers_resource_id_pattern_idx" ON "auth"."sso_providers" USING "btree" ("resource_id" "text_pattern_ops");



CREATE UNIQUE INDEX "unique_phone_factor_per_user" ON "auth"."mfa_factors" USING "btree" ("user_id", "phone");



CREATE INDEX "user_id_created_at_idx" ON "auth"."sessions" USING "btree" ("user_id", "created_at");



CREATE UNIQUE INDEX "users_email_partial_key" ON "auth"."users" USING "btree" ("email") WHERE ("is_sso_user" = false);



COMMENT ON INDEX "auth"."users_email_partial_key" IS 'Auth: A partial unique index that applies only when is_sso_user is false';



CREATE INDEX "users_instance_id_email_idx" ON "auth"."users" USING "btree" ("instance_id", "lower"(("email")::"text"));



CREATE INDEX "users_instance_id_idx" ON "auth"."users" USING "btree" ("instance_id");



CREATE INDEX "users_is_anonymous_idx" ON "auth"."users" USING "btree" ("is_anonymous");



CREATE INDEX "idx_account_deletion_audit_action" ON "public"."account_deletion_audit" USING "btree" ("action");



CREATE INDEX "idx_account_deletion_audit_created_at" ON "public"."account_deletion_audit" USING "btree" ("created_at");



CREATE INDEX "idx_account_deletion_audit_user_id" ON "public"."account_deletion_audit" USING "btree" ("user_id");



CREATE INDEX "idx_audit_logs_created_at" ON "public"."audit_logs" USING "btree" ("created_at");



CREATE INDEX "idx_audit_logs_table_record" ON "public"."audit_logs" USING "btree" ("table_name", "record_id");



CREATE INDEX "idx_billing_history_organization_id" ON "public"."billing_history" USING "btree" ("organization_id");



CREATE INDEX "idx_billing_history_subscription_id" ON "public"."billing_history" USING "btree" ("subscription_id");



CREATE INDEX "idx_cartons_carton_barcode" ON "public"."cartons" USING "btree" ("carton_barcode");



CREATE INDEX "idx_cartons_organization_id" ON "public"."cartons" USING "btree" ("organization_id");



CREATE INDEX "idx_cartons_product_id" ON "public"."cartons" USING "btree" ("product_id");



CREATE INDEX "idx_categories_org_grid" ON "public"."categories" USING "btree" ("organization_id", "grid_number");



CREATE INDEX "idx_categories_organization_id" ON "public"."categories" USING "btree" ("organization_id");



CREATE INDEX "idx_category_availability_cat" ON "public"."category_availability" USING "btree" ("category_id");



CREATE INDEX "idx_category_availability_store_id" ON "public"."category_availability" USING "btree" ("store_id");



CREATE INDEX "idx_change_logs_synced_at" ON "public"."change_logs" USING "btree" ("synced_at") WHERE ("synced_at" IS NULL);



CREATE INDEX "idx_change_logs_table_record" ON "public"."change_logs" USING "btree" ("table_name", "record_id");



CREATE INDEX "idx_coupons_active_expires" ON "public"."coupons" USING "btree" ("is_active", "expires_at");



CREATE INDEX "idx_coupons_organization_id" ON "public"."coupons" USING "btree" ("organization_id");



CREATE INDEX "idx_customer_display_sessions_active" ON "public"."customer_display_sessions" USING "btree" ("is_active");



CREATE INDEX "idx_customer_display_sessions_active_expires" ON "public"."customer_display_sessions" USING "btree" ("is_active", "expires_at");



CREATE INDEX "idx_customer_display_sessions_display_active" ON "public"."customer_display_sessions" USING "btree" ("display_id", "is_active");



CREATE INDEX "idx_customer_display_sessions_display_id" ON "public"."customer_display_sessions" USING "btree" ("display_id");



CREATE INDEX "idx_customer_display_sessions_expires_at" ON "public"."customer_display_sessions" USING "btree" ("expires_at");



CREATE INDEX "idx_customer_display_sessions_organization_id" ON "public"."customer_display_sessions" USING "btree" ("organization_id");



CREATE INDEX "idx_customer_display_sessions_status" ON "public"."customer_display_sessions" USING "btree" ("status");



CREATE INDEX "idx_customer_display_sessions_store_id" ON "public"."customer_display_sessions" USING "btree" ("store_id");



CREATE INDEX "idx_customer_displays_organization_id" ON "public"."customer_displays" USING "btree" ("organization_id");



CREATE INDEX "idx_customer_displays_store_id" ON "public"."customer_displays" USING "btree" ("store_id");



CREATE INDEX "idx_device_settings_store_id" ON "public"."device_settings" USING "btree" ("store_id");



CREATE INDEX "idx_dining_options_organization_id" ON "public"."dining_options" USING "btree" ("organization_id");



CREATE INDEX "idx_initialization_history_created_at" ON "public"."initialization_history" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_initialization_history_created_by" ON "public"."initialization_history" USING "btree" ("created_by");



CREATE INDEX "idx_initialization_history_org_id" ON "public"."initialization_history" USING "btree" ("organization_id");



CREATE INDEX "idx_initialization_history_store_id" ON "public"."initialization_history" USING "btree" ("store_id");



CREATE INDEX "idx_initialization_templates_created_by" ON "public"."initialization_templates" USING "btree" ("created_by");



CREATE INDEX "idx_initialization_templates_is_default" ON "public"."initialization_templates" USING "btree" ("is_default");



CREATE INDEX "idx_initialization_templates_org_id" ON "public"."initialization_templates" USING "btree" ("organization_id");



CREATE INDEX "idx_inventory_history_change_type" ON "public"."inventory_history" USING "btree" ("change_type");



CREATE INDEX "idx_inventory_history_inventory_id" ON "public"."inventory_history" USING "btree" ("inventory_id");



CREATE INDEX "idx_inventory_history_organization_id" ON "public"."inventory_history" USING "btree" ("organization_id");



CREATE INDEX "idx_inventory_history_product_id" ON "public"."inventory_history" USING "btree" ("product_id");



CREATE INDEX "idx_inventory_history_store_id" ON "public"."inventory_history" USING "btree" ("store_id");



CREATE INDEX "idx_inventory_product_id" ON "public"."inventory" USING "btree" ("product_id");



CREATE INDEX "idx_inventory_store_id" ON "public"."inventory" USING "btree" ("store_id");



CREATE INDEX "idx_kitchen_displays_org_store" ON "public"."kitchen_displays" USING "btree" ("organization_id", "store_id");



CREATE INDEX "idx_kitchen_displays_store_id" ON "public"."kitchen_displays" USING "btree" ("store_id");



CREATE INDEX "idx_modified_order_items_modified_by" ON "public"."modified_order_items" USING "btree" ("modified_by");



CREATE INDEX "idx_modified_order_items_order_id" ON "public"."modified_order_items" USING "btree" ("order_id");



CREATE INDEX "idx_modified_order_items_original_item_id" ON "public"."modified_order_items" USING "btree" ("original_item_id");



CREATE INDEX "idx_modified_order_items_product_id" ON "public"."modified_order_items" USING "btree" ("product_id");



CREATE INDEX "idx_netvisor_refund_history_mod" ON "public"."netvisor_refund_history" USING "btree" ("transaction_modification_id");



CREATE INDEX "idx_netvisor_refund_history_order_id" ON "public"."netvisor_refund_history" USING "btree" ("order_id");



CREATE INDEX "idx_netvisor_refund_history_org" ON "public"."netvisor_refund_history" USING "btree" ("organization_id");



CREATE INDEX "idx_netvisor_refund_history_status" ON "public"."netvisor_refund_history" USING "btree" ("status");



CREATE INDEX "idx_netvisor_sync_history_organization_id" ON "public"."netvisor_sync_history" USING "btree" ("organization_id");



CREATE INDEX "idx_netvisor_sync_history_store_id" ON "public"."netvisor_sync_history" USING "btree" ("store_id");



CREATE INDEX "idx_note_templates_created_by" ON "public"."note_templates" USING "btree" ("created_by");



CREATE INDEX "idx_note_templates_is_active" ON "public"."note_templates" USING "btree" ("is_active");



CREATE INDEX "idx_note_templates_org_active_sort" ON "public"."note_templates" USING "btree" ("organization_id", "is_active", "sort_order");



CREATE INDEX "idx_note_templates_organization_id" ON "public"."note_templates" USING "btree" ("organization_id");



CREATE INDEX "idx_note_templates_sort_order" ON "public"."note_templates" USING "btree" ("sort_order");



CREATE INDEX "idx_order_commits_order_id" ON "public"."order_commits" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_active" ON "public"."order_items" USING "btree" ("order_id") WHERE ("status" = 'active'::"text");



COMMENT ON INDEX "public"."idx_order_items_active" IS 'Partial index for active order items - optimizes Cart queries';



CREATE INDEX "idx_order_items_cancelled" ON "public"."order_items" USING "btree" ("order_id", "updated_at") WHERE ("status" = 'cancelled'::"text");



COMMENT ON INDEX "public"."idx_order_items_cancelled" IS 'Partial index for cancelled order items - optimizes reporting queries';



CREATE INDEX "idx_order_items_coupon_id" ON "public"."order_items" USING "btree" ("coupon_id");



CREATE INDEX "idx_order_items_kds_pending_ready" ON "public"."order_items" USING "btree" ((("display_status")::"text")) WHERE (("status" = 'active'::"text") AND ((("display_status")::"text" ~~ '%"status":"pending"%'::"text") OR (("display_status")::"text" ~~ '%"status":"ready"%'::"text")));



COMMENT ON INDEX "public"."idx_order_items_kds_pending_ready" IS 'Optimizes queries filtering items with pending or ready status. Used by both KDS (pending/ready) and SDS (ready only) displays.';



CREATE INDEX "idx_order_items_kds_status_gin" ON "public"."order_items" USING "gin" ("display_status");



COMMENT ON INDEX "public"."idx_order_items_kds_status_gin" IS 'GIN index for fast JSONB queries. Enables efficient searches for any key or value within kds_status.';



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_order_status" ON "public"."order_items" USING "btree" ("order_id", "status") WHERE ("status" = 'active'::"text");



COMMENT ON INDEX "public"."idx_order_items_order_status" IS 'Optimizes lookup of active order items by order';



CREATE INDEX "idx_order_items_product_id" ON "public"."order_items" USING "btree" ("product_id");



CREATE INDEX "idx_order_items_product_order" ON "public"."order_items" USING "btree" ("product_id", "order_id") WHERE ("status" = 'active'::"text");



COMMENT ON INDEX "public"."idx_order_items_product_order" IS 'Optimizes product aggregation queries in cart loading';



CREATE INDEX "idx_order_items_sds_ready" ON "public"."order_items" USING "btree" ((("display_status")::"text")) WHERE (("status" = 'active'::"text") AND (("display_status")::"text" ~~ '%"status":"ready"%'::"text"));



COMMENT ON INDEX "public"."idx_order_items_sds_ready" IS 'Optimizes SDS queries filtering items with ready status (waiting for service). More selective than the KDS index.';



CREATE INDEX "idx_order_restore_requests_order_id" ON "public"."order_restore_requests" USING "btree" ("order_id");



CREATE INDEX "idx_order_restore_requests_processed" ON "public"."order_restore_requests" USING "btree" ("processed") WHERE (NOT "processed");



CREATE INDEX "idx_order_restore_requests_store_id" ON "public"."order_restore_requests" USING "btree" ("store_id");



CREATE INDEX "idx_order_sequences_store_date" ON "public"."order_sequences" USING "btree" ("store_id", "sequence_date");



CREATE INDEX "idx_orders_coupon_id" ON "public"."orders" USING "btree" ("coupon_id");



CREATE INDEX "idx_orders_created_at" ON "public"."orders" USING "btree" ("created_at");



CREATE INDEX "idx_orders_dining_option" ON "public"."orders" USING "btree" ("dining_option");



CREATE INDEX "idx_orders_discount_amount_gin" ON "public"."orders" USING "gin" ("discount_amount");



CREATE INDEX "idx_orders_kitchen_status" ON "public"."orders" USING "btree" ("kitchen_status") WHERE (("kitchen_status")::"text" = ANY ((ARRAY['pending'::character varying, 'preparing'::character varying])::"text"[]));



CREATE INDEX "idx_orders_order_coupon_discount_total" ON "public"."orders" USING "btree" ("order_coupon_discount_total") WHERE ("order_coupon_discount_total" > (0)::numeric);



CREATE INDEX "idx_orders_organization_id" ON "public"."orders" USING "btree" ("organization_id");



CREATE INDEX "idx_orders_payment_method" ON "public"."orders" USING "btree" ("payment_types");



CREATE INDEX "idx_orders_receipt_number" ON "public"."orders" USING "btree" ("receipt_number") WHERE ("receipt_number" IS NOT NULL);



CREATE INDEX "idx_orders_session_status" ON "public"."orders" USING "btree" ("table_session_id", "status") WHERE ("status" = 'unpaid'::"public"."order_status");



COMMENT ON INDEX "public"."idx_orders_session_status" IS 'Optimizes lookup of unpaid orders by table session';



CREATE INDEX "idx_orders_split_bill_info_original_order_id" ON "public"."orders" USING "btree" ((("split_bill_info" ->> 'original_order_id'::"text"))) WHERE ("split_bill_info" IS NOT NULL);



CREATE INDEX "idx_orders_status" ON "public"."orders" USING "btree" ("status");



CREATE INDEX "idx_orders_store_id" ON "public"."orders" USING "btree" ("store_id");



CREATE INDEX "idx_orders_table_session" ON "public"."orders" USING "btree" ("table_session_id") WHERE ("table_session_id" IS NOT NULL);



COMMENT ON INDEX "public"."idx_orders_table_session" IS 'Partial index for orders linked to table sessions - optimizes session order queries';



CREATE INDEX "idx_orders_table_session_id" ON "public"."orders" USING "btree" ("table_session_id");



CREATE INDEX "idx_orders_table_session_unpaid" ON "public"."orders" USING "btree" ("table_session_id", "status") WHERE ("status" = 'unpaid'::"public"."order_status");



COMMENT ON INDEX "public"."idx_orders_table_session_unpaid" IS 'Composite index for unpaid orders by session - optimizes payment completion queries';



CREATE INDEX "idx_orders_tax_breakdown_gin" ON "public"."orders" USING "gin" ("tax_amount");



CREATE INDEX "idx_orders_user_id" ON "public"."orders" USING "btree" ("user_id");



CREATE INDEX "idx_organizations_deletion_requested_at" ON "public"."organizations" USING "btree" ("deletion_requested_at") WHERE ("deletion_requested_at" IS NOT NULL);



CREATE INDEX "idx_organizations_hard_delete_after" ON "public"."organizations" USING "btree" ("hard_delete_after") WHERE ("hard_delete_after" IS NOT NULL);



CREATE INDEX "idx_organizations_lifecycle_status" ON "public"."organizations" USING "btree" ("lifecycle_status");



CREATE INDEX "idx_payment_types_organization_id" ON "public"."payment_types" USING "btree" ("organization_id");



CREATE INDEX "idx_pos_settings_organization_id" ON "public"."pos_settings" USING "btree" ("organization_id");



CREATE INDEX "idx_printers_organization_id" ON "public"."printers" USING "btree" ("organization_id");



CREATE INDEX "idx_printers_printer_categories" ON "public"."printers" USING "gin" ("printer_categories");



CREATE INDEX "idx_printers_store_id" ON "public"."printers" USING "btree" ("store_id");



CREATE INDEX "idx_products_barcode" ON "public"."products" USING "btree" ("barcode");



CREATE INDEX "idx_products_category_id" ON "public"."products" USING "btree" ("category_id");



CREATE INDEX "idx_products_org_cat_grid" ON "public"."products" USING "btree" ("organization_id", "category_id", "grid_number");



CREATE INDEX "idx_products_organization_id" ON "public"."products" USING "btree" ("organization_id");



CREATE INDEX "idx_products_organization_sku" ON "public"."products" USING "btree" ("organization_id", "sku") WHERE ("sku" IS NOT NULL);



CREATE INDEX "idx_products_sku" ON "public"."products" USING "btree" ("sku");



CREATE INDEX "idx_receipt_number_sequences_store_id" ON "public"."receipt_number_sequences" USING "btree" ("store_id");



CREATE INDEX "idx_receipt_settings_store_id" ON "public"."receipt_settings" USING "btree" ("store_id");



CREATE INDEX "idx_self_order_displays_device_id" ON "public"."bos_displays" USING "btree" ("device_id");



CREATE INDEX "idx_self_order_displays_display_type" ON "public"."bos_displays" USING "btree" ("display_type");



CREATE INDEX "idx_self_order_displays_org_id" ON "public"."bos_displays" USING "btree" ("organization_id");



CREATE INDEX "idx_self_order_displays_status" ON "public"."bos_displays" USING "btree" ("status");



CREATE INDEX "idx_self_order_displays_store_id" ON "public"."bos_displays" USING "btree" ("store_id");



CREATE INDEX "idx_server_displays_organization_id" ON "public"."server_displays" USING "btree" ("organization_id");



CREATE INDEX "idx_server_displays_store_id" ON "public"."server_displays" USING "btree" ("store_id");



CREATE INDEX "idx_stores_organization_id" ON "public"."stores" USING "btree" ("organization_id");



CREATE INDEX "idx_subscriptions_organization_id" ON "public"."subscriptions" USING "btree" ("organization_id");



CREATE INDEX "idx_subscriptions_plan_id" ON "public"."subscriptions" USING "btree" ("plan_id");



CREATE INDEX "idx_table_sessions_active" ON "public"."table_sessions" USING "btree" ("organization_id", "table_number") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_table_sessions_org_store_status" ON "public"."table_sessions" USING "btree" ("organization_id", "store_id", "status");



CREATE INDEX "idx_table_sessions_org_table_status" ON "public"."table_sessions" USING "btree" ("organization_id", "table_number", "status");



COMMENT ON INDEX "public"."idx_table_sessions_org_table_status" IS 'Composite index for filtering sessions by organization, table number, and status';



CREATE INDEX "idx_table_sessions_organization_id" ON "public"."table_sessions" USING "btree" ("organization_id");



CREATE INDEX "idx_table_sessions_status" ON "public"."table_sessions" USING "btree" ("status");



COMMENT ON INDEX "public"."idx_table_sessions_status" IS 'Partial index for active sessions - optimizes session list queries';



CREATE INDEX "idx_table_sessions_store_id" ON "public"."table_sessions" USING "btree" ("store_id");



CREATE INDEX "idx_table_sessions_table_number" ON "public"."table_sessions" USING "btree" ("table_number");



CREATE INDEX "idx_table_sessions_table_number_status_store" ON "public"."table_sessions" USING "btree" ("table_number", "status", "store_id") WHERE ("status" = 'active'::"text");



COMMENT ON INDEX "public"."idx_table_sessions_table_number_status_store" IS 'Optimizes lookup of active table sessions by table number and store';



CREATE UNIQUE INDEX "idx_table_sessions_unique_active" ON "public"."table_sessions" USING "btree" ("organization_id", "store_id", "table_number", "status") WHERE ("status" = 'active'::"text");



COMMENT ON INDEX "public"."idx_table_sessions_unique_active" IS 'Ensures only one active session per table per store within an organization';



CREATE INDEX "idx_tax_settings_organization_id" ON "public"."tax_settings" USING "btree" ("organization_id");



CREATE INDEX "idx_tos_displays_organization_id" ON "public"."tos_displays" USING "btree" ("organization_id");



CREATE INDEX "idx_tos_displays_status" ON "public"."tos_displays" USING "btree" ("status");



CREATE INDEX "idx_tos_displays_store_id" ON "public"."tos_displays" USING "btree" ("store_id");



CREATE INDEX "idx_tos_sessions_active" ON "public"."tos_sessions" USING "btree" ("active");



CREATE INDEX "idx_tos_sessions_dining_option_id" ON "public"."tos_sessions" USING "btree" ("dining_option_id");



CREATE INDEX "idx_tos_sessions_organization_id" ON "public"."tos_sessions" USING "btree" ("organization_id");



CREATE INDEX "idx_tos_sessions_qr_code" ON "public"."tos_sessions" USING "btree" ("session_qr_code");



CREATE INDEX "idx_tos_sessions_store_id" ON "public"."tos_sessions" USING "btree" ("store_id");



CREATE INDEX "idx_tos_sessions_table_number" ON "public"."tos_sessions" USING "btree" ("table_number");



CREATE INDEX "idx_transaction_modifications_approved_by" ON "public"."transaction_modifications" USING "btree" ("approved_by");



CREATE INDEX "idx_transaction_modifications_order_id" ON "public"."transaction_modifications" USING "btree" ("order_id");



CREATE INDEX "idx_transaction_modifications_organization_id" ON "public"."transaction_modifications" USING "btree" ("organization_id");



CREATE INDEX "idx_transaction_modifications_processed_by" ON "public"."transaction_modifications" USING "btree" ("processed_by");



CREATE INDEX "idx_transaction_modifications_requested_by" ON "public"."transaction_modifications" USING "btree" ("requested_by");



CREATE INDEX "idx_transaction_modifications_status" ON "public"."transaction_modifications" USING "btree" ("status");



CREATE INDEX "idx_user_store_roles_role" ON "public"."user_store_roles" USING "btree" ("role");



CREATE INDEX "idx_user_store_roles_store_id" ON "public"."user_store_roles" USING "btree" ("store_id");



CREATE INDEX "idx_user_store_roles_user_id" ON "public"."user_store_roles" USING "btree" ("user_id");



CREATE INDEX "idx_users_anonymized_at" ON "public"."users" USING "btree" ("anonymized_at") WHERE ("anonymized_at" IS NOT NULL);



CREATE INDEX "idx_users_deletion_requested_at" ON "public"."users" USING "btree" ("deletion_requested_at") WHERE ("deletion_requested_at" IS NOT NULL);



CREATE INDEX "idx_users_deletion_scheduled_at" ON "public"."users" USING "btree" ("deletion_scheduled_at") WHERE ("deletion_scheduled_at" IS NOT NULL);



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_is_deleted" ON "public"."users" USING "btree" ("is_deleted") WHERE ("is_deleted" = true);



CREATE INDEX "idx_users_organization_id" ON "public"."users" USING "btree" ("organization_id");



CREATE INDEX "idx_users_role" ON "public"."users" USING "btree" ("role");



CREATE INDEX "organizations_slug_idx" ON "public"."organizations" USING "btree" ("slug");



CREATE INDEX "product_availabilities_product_idx" ON "public"."product_availabilities" USING "btree" ("product_id");



CREATE INDEX "product_availabilities_store_idx" ON "public"."product_availabilities" USING "btree" ("store_id");



CREATE UNIQUE INDEX "user_store_roles_user_id_store_id_key" ON "public"."user_store_roles" USING "btree" ("user_id", "store_id") WHERE (("user_id" IS NOT NULL) AND ("store_id" IS NOT NULL));



CREATE UNIQUE INDEX "bname" ON "storage"."buckets" USING "btree" ("name");



CREATE UNIQUE INDEX "bucketid_objname" ON "storage"."objects" USING "btree" ("bucket_id", "name");



CREATE UNIQUE INDEX "buckets_analytics_unique_name_idx" ON "storage"."buckets_analytics" USING "btree" ("name") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_multipart_uploads_list" ON "storage"."s3_multipart_uploads" USING "btree" ("bucket_id", "key", "created_at");



CREATE UNIQUE INDEX "idx_name_bucket_level_unique" ON "storage"."objects" USING "btree" ("name" COLLATE "C", "bucket_id", "level");



CREATE INDEX "idx_objects_bucket_id_name" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C");



CREATE INDEX "idx_objects_lower_name" ON "storage"."objects" USING "btree" (("path_tokens"["level"]), "lower"("name") "text_pattern_ops", "bucket_id", "level");



CREATE INDEX "idx_prefixes_lower_name" ON "storage"."prefixes" USING "btree" ("bucket_id", "level", (("string_to_array"("name", '/'::"text"))["level"]), "lower"("name") "text_pattern_ops");



CREATE INDEX "name_prefix_search" ON "storage"."objects" USING "btree" ("name" "text_pattern_ops");



CREATE UNIQUE INDEX "objects_bucket_id_level_idx" ON "storage"."objects" USING "btree" ("bucket_id", "level", "name" COLLATE "C");



CREATE UNIQUE INDEX "vector_indexes_name_bucket_id_idx" ON "storage"."vector_indexes" USING "btree" ("name", "bucket_id");



CREATE OR REPLACE TRIGGER "audit_inventory" AFTER INSERT OR DELETE OR UPDATE ON "public"."inventory" FOR EACH ROW EXECUTE FUNCTION "public"."audit_trigger"();



CREATE OR REPLACE TRIGGER "audit_orders" AFTER INSERT OR DELETE OR UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."audit_trigger"();



CREATE OR REPLACE TRIGGER "audit_organizations" AFTER INSERT OR DELETE OR UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."audit_trigger"();



CREATE OR REPLACE TRIGGER "audit_products" AFTER INSERT OR DELETE OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."audit_trigger"();



CREATE OR REPLACE TRIGGER "audit_stores" AFTER INSERT OR DELETE OR UPDATE ON "public"."stores" FOR EACH ROW EXECUTE FUNCTION "public"."audit_trigger"();



CREATE OR REPLACE TRIGGER "audit_users" AFTER INSERT OR DELETE OR UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."audit_trigger"();



CREATE OR REPLACE TRIGGER "broadcast_order_insert_trigger" AFTER INSERT ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_new_order"();



CREATE OR REPLACE TRIGGER "broadcast_order_update_trigger" AFTER UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_order_update"();



CREATE OR REPLACE TRIGGER "cds_sessions_completed_migration_trigger" AFTER INSERT OR DELETE OR UPDATE ON "public"."customer_display_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."notify_cds_session_change_completed_migration"();



CREATE OR REPLACE TRIGGER "change_log_categories" AFTER INSERT OR DELETE OR UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."change_log_trigger"();



CREATE OR REPLACE TRIGGER "change_log_inventory" AFTER INSERT OR DELETE OR UPDATE ON "public"."inventory" FOR EACH ROW EXECUTE FUNCTION "public"."change_log_trigger"();



CREATE OR REPLACE TRIGGER "change_log_order_items" AFTER INSERT OR DELETE OR UPDATE ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."change_log_trigger"();



CREATE OR REPLACE TRIGGER "change_log_orders" AFTER INSERT OR DELETE OR UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."change_log_trigger"();



CREATE OR REPLACE TRIGGER "change_log_organizations" AFTER INSERT OR DELETE OR UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."change_log_trigger"();



CREATE OR REPLACE TRIGGER "change_log_products" AFTER INSERT OR DELETE OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."change_log_trigger"();



CREATE OR REPLACE TRIGGER "change_log_stores" AFTER INSERT OR DELETE OR UPDATE ON "public"."stores" FOR EACH ROW EXECUTE FUNCTION "public"."change_log_trigger"();



CREATE OR REPLACE TRIGGER "kds_orders_change_trigger" AFTER INSERT OR DELETE OR UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."notify_kds_order_change"();



CREATE OR REPLACE TRIGGER "kds_orders_delete_trigger" AFTER DELETE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."notify_kds_order_change"();



CREATE OR REPLACE TRIGGER "kds_orders_insert_trigger" AFTER INSERT ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."notify_kds_order_change"();



CREATE OR REPLACE TRIGGER "kds_orders_update_trigger" AFTER UPDATE ON "public"."orders" FOR EACH ROW WHEN (((("old"."kitchen_status")::"text" IS DISTINCT FROM ("new"."kitchen_status")::"text") OR ("old"."status" IS DISTINCT FROM "new"."status") OR ("old"."kitchen_started_at" IS DISTINCT FROM "new"."kitchen_started_at") OR ("old"."kitchen_completed_at" IS DISTINCT FROM "new"."kitchen_completed_at"))) EXECUTE FUNCTION "public"."notify_kds_order_change"();



CREATE OR REPLACE TRIGGER "order_restore_processor_trigger" AFTER INSERT ON "public"."order_restore_requests" FOR EACH ROW EXECUTE FUNCTION "public"."process_order_restore"();



CREATE OR REPLACE TRIGGER "trigger_cds_session_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."customer_display_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."notify_cds_session_change"();



CREATE OR REPLACE TRIGGER "trigger_notify_category_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."notify_category_changes"();



CREATE OR REPLACE TRIGGER "trigger_notify_product_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."notify_product_changes"();



CREATE OR REPLACE TRIGGER "trigger_recalculate_order_totals" AFTER INSERT OR DELETE OR UPDATE OF "status", "quantity", "unit_price", "discount_amount", "tax_rate", "manual_discount_amount", "order_coupon_discount", "item_coupon_discount" ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."recalculate_order_totals"();



CREATE OR REPLACE TRIGGER "trigger_set_category_grid_number" BEFORE INSERT ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_category_grid_number"();



CREATE OR REPLACE TRIGGER "trigger_set_product_grid_number" BEFORE INSERT ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_product_grid_number"();



CREATE OR REPLACE TRIGGER "trigger_update_self_order_displays_updated_at" BEFORE UPDATE ON "public"."bos_displays" FOR EACH ROW EXECUTE FUNCTION "public"."update_self_order_displays_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_update_table_sessions_updated_at" BEFORE UPDATE ON "public"."table_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."update_table_sessions_updated_at"();



CREATE OR REPLACE TRIGGER "update_categories_updated_at" BEFORE UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_coupons_updated_at_trigger" BEFORE UPDATE ON "public"."coupons" FOR EACH ROW EXECUTE FUNCTION "public"."update_coupons_updated_at"();



CREATE OR REPLACE TRIGGER "update_customer_display_sessions_updated_at" BEFORE UPDATE ON "public"."customer_display_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_customer_displays_updated_at" BEFORE UPDATE ON "public"."customer_displays" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_device_settings_updated_at" BEFORE UPDATE ON "public"."device_settings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_inventory_trigger" AFTER UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_inventory_on_order"();



CREATE OR REPLACE TRIGGER "update_inventory_updated_at" BEFORE UPDATE ON "public"."inventory" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_note_templates_updated_at" BEFORE UPDATE ON "public"."note_templates" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_order_sequences_updated_at_trigger" BEFORE UPDATE ON "public"."order_sequences" FOR EACH ROW EXECUTE FUNCTION "public"."update_order_sequences_updated_at"();



CREATE OR REPLACE TRIGGER "update_orders_updated_at" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_organizations_updated_at" BEFORE UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_products_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_receipt_number_sequences_updated_at_trigger" BEFORE UPDATE ON "public"."receipt_number_sequences" FOR EACH ROW EXECUTE FUNCTION "public"."update_receipt_number_sequences_updated_at"();



CREATE OR REPLACE TRIGGER "update_stores_updated_at" BEFORE UPDATE ON "public"."stores" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_tos_sessions_updated_at" BEFORE UPDATE ON "public"."tos_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."update_tos_sessions_updated_at"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "enforce_bucket_name_length_trigger" BEFORE INSERT OR UPDATE OF "name" ON "storage"."buckets" FOR EACH ROW EXECUTE FUNCTION "storage"."enforce_bucket_name_length"();



CREATE OR REPLACE TRIGGER "objects_delete_delete_prefix" AFTER DELETE ON "storage"."objects" FOR EACH ROW EXECUTE FUNCTION "storage"."delete_prefix_hierarchy_trigger"();



CREATE OR REPLACE TRIGGER "objects_insert_create_prefix" BEFORE INSERT ON "storage"."objects" FOR EACH ROW EXECUTE FUNCTION "storage"."objects_insert_prefix_trigger"();



CREATE OR REPLACE TRIGGER "objects_update_create_prefix" BEFORE UPDATE ON "storage"."objects" FOR EACH ROW WHEN ((("new"."name" <> "old"."name") OR ("new"."bucket_id" <> "old"."bucket_id"))) EXECUTE FUNCTION "storage"."objects_update_prefix_trigger"();



CREATE OR REPLACE TRIGGER "prefixes_create_hierarchy" BEFORE INSERT ON "storage"."prefixes" FOR EACH ROW WHEN (("pg_trigger_depth"() < 1)) EXECUTE FUNCTION "storage"."prefixes_insert_trigger"();



CREATE OR REPLACE TRIGGER "prefixes_delete_hierarchy" AFTER DELETE ON "storage"."prefixes" FOR EACH ROW EXECUTE FUNCTION "storage"."delete_prefix_hierarchy_trigger"();



CREATE OR REPLACE TRIGGER "update_objects_updated_at" BEFORE UPDATE ON "storage"."objects" FOR EACH ROW EXECUTE FUNCTION "storage"."update_updated_at_column"();



ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "mfa_amr_claims_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "auth"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."mfa_challenges"
    ADD CONSTRAINT "mfa_challenges_auth_factor_id_fkey" FOREIGN KEY ("factor_id") REFERENCES "auth"."mfa_factors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."one_time_tokens"
    ADD CONSTRAINT "one_time_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "auth"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_flow_state_id_fkey" FOREIGN KEY ("flow_state_id") REFERENCES "auth"."flow_state"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_oauth_client_id_fkey" FOREIGN KEY ("oauth_client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."sso_domains"
    ADD CONSTRAINT "sso_domains_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."account_deletion_audit"
    ADD CONSTRAINT "account_deletion_audit_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."billing_history"
    ADD CONSTRAINT "billing_history_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."billing_history"
    ADD CONSTRAINT "billing_history_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "public"."subscriptions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cartons"
    ADD CONSTRAINT "cartons_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cartons"
    ADD CONSTRAINT "cartons_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."category_availability"
    ADD CONSTRAINT "category_availability_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."category_availability"
    ADD CONSTRAINT "category_availability_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."coupons"
    ADD CONSTRAINT "coupons_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customer_display_sessions"
    ADD CONSTRAINT "customer_display_sessions_display_id_fkey" FOREIGN KEY ("display_id") REFERENCES "public"."customer_displays"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customer_display_sessions"
    ADD CONSTRAINT "customer_display_sessions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."customer_display_sessions"
    ADD CONSTRAINT "customer_display_sessions_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."customer_displays"
    ADD CONSTRAINT "customer_displays_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customer_displays"
    ADD CONSTRAINT "customer_displays_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."device_settings"
    ADD CONSTRAINT "device_settings_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."device_settings"
    ADD CONSTRAINT "device_settings_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."dining_options"
    ADD CONSTRAINT "dining_options_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_templates"
    ADD CONSTRAINT "fk_note_templates_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "fk_order_items_coupon" FOREIGN KEY ("coupon_id") REFERENCES "public"."coupons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "fk_orders_coupon" FOREIGN KEY ("coupon_id") REFERENCES "public"."coupons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "fk_orders_dining_option" FOREIGN KEY ("dining_option") REFERENCES "public"."dining_options"("id");



ALTER TABLE ONLY "public"."initialization_history"
    ADD CONSTRAINT "initialization_history_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."initialization_history"
    ADD CONSTRAINT "initialization_history_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."initialization_history"
    ADD CONSTRAINT "initialization_history_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."initialization_templates"
    ADD CONSTRAINT "initialization_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."initialization_templates"
    ADD CONSTRAINT "initialization_templates_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_history"
    ADD CONSTRAINT "inventory_history_inventory_id_fkey" FOREIGN KEY ("inventory_id") REFERENCES "public"."inventory"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_history"
    ADD CONSTRAINT "inventory_history_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_history"
    ADD CONSTRAINT "inventory_history_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_history"
    ADD CONSTRAINT "inventory_history_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory"
    ADD CONSTRAINT "inventory_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory"
    ADD CONSTRAINT "inventory_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_displays"
    ADD CONSTRAINT "kitchen_displays_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_displays"
    ADD CONSTRAINT "kitchen_displays_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."modified_order_items"
    ADD CONSTRAINT "modified_order_items_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."modified_order_items"
    ADD CONSTRAINT "modified_order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."modified_order_items"
    ADD CONSTRAINT "modified_order_items_original_item_id_fkey" FOREIGN KEY ("original_item_id") REFERENCES "public"."order_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."modified_order_items"
    ADD CONSTRAINT "modified_order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."netvisor_products"
    ADD CONSTRAINT "netvisor_products_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."netvisor_refund_history"
    ADD CONSTRAINT "netvisor_refund_history_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."netvisor_refund_history"
    ADD CONSTRAINT "netvisor_refund_history_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."netvisor_refund_history"
    ADD CONSTRAINT "netvisor_refund_history_transaction_modification_id_fkey" FOREIGN KEY ("transaction_modification_id") REFERENCES "public"."transaction_modifications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."netvisor_settings"
    ADD CONSTRAINT "netvisor_settings_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."netvisor_sync_history"
    ADD CONSTRAINT "netvisor_sync_history_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."netvisor_sync_history"
    ADD CONSTRAINT "netvisor_sync_history_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."note_templates"
    ADD CONSTRAINT "note_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."order_commits"
    ADD CONSTRAINT "order_commits_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_restore_requests"
    ADD CONSTRAINT "order_restore_requests_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_sequences"
    ADD CONSTRAINT "order_sequences_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_payment_types_fkey" FOREIGN KEY ("payment_types") REFERENCES "public"."payment_types"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."payment_types"
    ADD CONSTRAINT "payment_types_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."printers"
    ADD CONSTRAINT "printers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."printers"
    ADD CONSTRAINT "printers_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."product_availabilities"
    ADD CONSTRAINT "product_availabilities_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_availabilities"
    ADD CONSTRAINT "product_availabilities_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."receipt_number_sequences"
    ADD CONSTRAINT "receipt_number_sequences_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."receipt_settings"
    ADD CONSTRAINT "receipt_settings_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."receipt_settings"
    ADD CONSTRAINT "receipt_settings_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bos_displays"
    ADD CONSTRAINT "self_order_displays_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bos_displays"
    ADD CONSTRAINT "self_order_displays_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."server_displays"
    ADD CONSTRAINT "server_displays_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."server_displays"
    ADD CONSTRAINT "server_displays_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."subscription_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."table_sessions"
    ADD CONSTRAINT "table_sessions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."table_sessions"
    ADD CONSTRAINT "table_sessions_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tax_settings"
    ADD CONSTRAINT "tax_settings_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tos_displays"
    ADD CONSTRAINT "tos_displays_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tos_displays"
    ADD CONSTRAINT "tos_displays_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tos_sessions"
    ADD CONSTRAINT "tos_sessions_dining_option_id_fkey" FOREIGN KEY ("dining_option_id") REFERENCES "public"."dining_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tos_sessions"
    ADD CONSTRAINT "tos_sessions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tos_sessions"
    ADD CONSTRAINT "tos_sessions_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transaction_modifications"
    ADD CONSTRAINT "transaction_modifications_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."transaction_modifications"
    ADD CONSTRAINT "transaction_modifications_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transaction_modifications"
    ADD CONSTRAINT "transaction_modifications_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transaction_modifications"
    ADD CONSTRAINT "transaction_modifications_processed_by_fkey" FOREIGN KEY ("processed_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."transaction_modifications"
    ADD CONSTRAINT "transaction_modifications_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_store_roles"
    ADD CONSTRAINT "user_store_roles_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_store_roles"
    ADD CONSTRAINT "user_store_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."prefixes"
    ADD CONSTRAINT "prefixes_bucketId_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_upload_id_fkey" FOREIGN KEY ("upload_id") REFERENCES "storage"."s3_multipart_uploads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets_vectors"("id");



ALTER TABLE "auth"."audit_log_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."flow_state" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."identities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."instances" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."mfa_amr_claims" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."mfa_challenges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."mfa_factors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."one_time_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."refresh_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."saml_providers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."saml_relay_states" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."schema_migrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."sso_domains" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."sso_providers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Admin and Manager can delete coupons" ON "public"."coupons" FOR DELETE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" IS NOT NULL) AND (("users"."role")::"text" = ANY ((ARRAY['Admin'::character varying, 'Manager'::character varying, 'owner'::character varying])::"text"[]))))));



CREATE POLICY "Admin and Manager can insert coupons" ON "public"."coupons" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" IS NOT NULL) AND (("users"."role")::"text" = ANY ((ARRAY['Admin'::character varying, 'Manager'::character varying, 'owner'::character varying])::"text"[]))))));



CREATE POLICY "Admin and Manager can update coupons" ON "public"."coupons" FOR UPDATE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" IS NOT NULL) AND (("users"."role")::"text" = ANY ((ARRAY['Admin'::character varying, 'Manager'::character varying, 'owner'::character varying])::"text"[])))))) WITH CHECK (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" IS NOT NULL) AND (("users"."role")::"text" = ANY ((ARRAY['Admin'::character varying, 'Manager'::character varying, 'owner'::character varying])::"text"[]))))));



CREATE POLICY "Allow anonymous read access to active customer displays" ON "public"."customer_displays" FOR SELECT TO "anon" USING (("active" = true));



CREATE POLICY "Allow authenticated users to view restore requests" ON "public"."order_restore_requests" FOR SELECT USING ((("store_id" IN ( SELECT "stores"."id"
   FROM "public"."stores"
  WHERE (("stores"."organization_id")::"text" = COALESCE((( SELECT "auth"."jwt"() AS "jwt") ->> 'organization_id'::"text"), ''::"text")))) OR (("store_id")::"text" = COALESCE((( SELECT "auth"."jwt"() AS "jwt") ->> 'store_id'::"text"), ''::"text"))));



CREATE POLICY "Allow service role full access" ON "public"."orders" TO "service_role" USING (true);



CREATE POLICY "Allow service role full restore access" ON "public"."order_restore_requests" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Global read access to default dining options" ON "public"."dining_options" FOR SELECT USING ((("organization_id" = '00000000-0000-0000-0000-000000000000'::"uuid") OR ("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Global read access to default payment types" ON "public"."payment_types" FOR SELECT USING ((("organization_id" = '00000000-0000-0000-0000-000000000000'::"uuid") OR ("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Global read access to default receipt settings" ON "public"."receipt_settings" FOR SELECT USING ((("organization_id" = '00000000-0000-0000-0000-000000000000'::"uuid") OR ("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Global read access to default tax settings" ON "public"."tax_settings" FOR SELECT USING ((("organization_id" = '00000000-0000-0000-0000-000000000000'::"uuid") OR ("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Organization admins can view deletion audits" ON "public"."account_deletion_audit" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = ( SELECT "users"."organization_id"
           FROM "public"."users"
          WHERE ("users"."id" = "account_deletion_audit"."user_id"))) AND (("u"."role")::"text" = ANY (ARRAY[('owner'::character varying)::"text", ('admin'::character varying)::"text"]))))));



CREATE POLICY "Owners and admins can update POS settings" ON "public"."pos_settings" FOR UPDATE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("users"."role")::"text" = ANY ((ARRAY['owner'::character varying, 'Admin'::character varying])::"text"[]))))));



CREATE POLICY "POS anonymous full access" ON "public"."customer_display_sessions" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "POS authenticated full access" ON "public"."customer_display_sessions" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Service role can manage order commits" ON "public"."order_commits" USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "Service role can manage refund history" ON "public"."netvisor_refund_history" USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "Users can access customer displays for their organization" ON "public"."customer_displays" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "customer_displays"."organization_id")))));



CREATE POLICY "Users can access their organization's self-order displays" ON "public"."bos_displays" USING (("organization_id" = (((( SELECT "current_setting"('request.jwt.claims'::"text", true) AS "current_setting"))::json ->> 'organization_id'::"text"))::"uuid"));



CREATE POLICY "Users can create bell order displays in their organization" ON "public"."bos_displays" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "bos_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can create kitchen displays in their organization" ON "public"."kitchen_displays" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "kitchen_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can delete bell order displays in their organization" ON "public"."bos_displays" FOR DELETE USING (("organization_id" IN ( SELECT "bos_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can delete coupons from their organization" ON "public"."coupons" FOR DELETE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can delete kitchen displays in their organization" ON "public"."kitchen_displays" FOR DELETE USING (("organization_id" IN ( SELECT "kitchen_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can delete note templates for their organization" ON "public"."note_templates" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "note_templates"."organization_id")))));



CREATE POLICY "Users can delete own organization receipt settings" ON "public"."receipt_settings" FOR DELETE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can delete server displays for their organization" ON "public"."server_displays" FOR DELETE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can delete tos_sessions" ON "public"."tos_sessions" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "tos_sessions"."organization_id")))));



CREATE POLICY "Users can insert coupons for their organization" ON "public"."coupons" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can insert note templates for their organization" ON "public"."note_templates" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "note_templates"."organization_id")))));



CREATE POLICY "Users can insert order items for their organization" ON "public"."order_items" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."orders"
  WHERE (("orders"."id" = "order_items"."order_id") AND ("orders"."organization_id" = ( SELECT "users"."organization_id"
           FROM "public"."users"
          WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Users can insert own organization receipt settings" ON "public"."receipt_settings" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can insert server displays for their organization" ON "public"."server_displays" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can insert tos_sessions" ON "public"."tos_sessions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "tos_sessions"."organization_id")))));



CREATE POLICY "Users can manage device settings in their organization" ON "public"."device_settings" USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can manage order sequences for their stores" ON "public"."order_sequences" USING ((EXISTS ( SELECT 1
   FROM ("public"."user_store_roles" "usr"
     JOIN "public"."stores" "s" ON (("s"."id" = "usr"."store_id")))
  WHERE (("usr"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("usr"."store_id" = "order_sequences"."store_id") AND ("usr"."is_active" = true)))));



CREATE POLICY "Users can manage printers for their organization" ON "public"."printers" USING (("organization_id" IN ( SELECT DISTINCT "stores"."organization_id"
   FROM ("public"."user_store_roles"
     JOIN "public"."stores" ON (("user_store_roles"."store_id" = "stores"."id")))
  WHERE (("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("user_store_roles"."is_active" = true))))) WITH CHECK (("organization_id" IN ( SELECT DISTINCT "stores"."organization_id"
   FROM ("public"."user_store_roles"
     JOIN "public"."stores" ON (("user_store_roles"."store_id" = "stores"."id")))
  WHERE (("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("user_store_roles"."is_active" = true)))));



CREATE POLICY "Users can manage printers for their_organization" ON "public"."printers" USING (("organization_id" IN ( SELECT DISTINCT "stores"."organization_id"
   FROM ("public"."user_store_roles"
     JOIN "public"."stores" ON (("user_store_roles"."store_id" = "stores"."id")))
  WHERE (("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("user_store_roles"."is_active" = true))))) WITH CHECK (("organization_id" IN ( SELECT DISTINCT "stores"."organization_id"
   FROM ("public"."user_store_roles"
     JOIN "public"."stores" ON (("user_store_roles"."store_id" = "stores"."id")))
  WHERE (("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("user_store_roles"."is_active" = true)))));



CREATE POLICY "Users can manage receipt number sequences for their stores" ON "public"."receipt_number_sequences" USING ((EXISTS ( SELECT 1
   FROM ("public"."user_store_roles" "usr"
     JOIN "public"."stores" "s" ON (("s"."id" = "usr"."store_id")))
  WHERE (("usr"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("usr"."store_id" = "receipt_number_sequences"."store_id") AND ("usr"."is_active" = true)))));



CREATE POLICY "Users can update bell order displays in their organization" ON "public"."bos_displays" FOR UPDATE USING (("organization_id" IN ( SELECT "bos_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can update coupons from their organization" ON "public"."coupons" FOR UPDATE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can update kitchen displays in their organization" ON "public"."kitchen_displays" FOR UPDATE USING (("organization_id" IN ( SELECT "kitchen_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can update note templates for their organization" ON "public"."note_templates" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "note_templates"."organization_id")))));



CREATE POLICY "Users can update order items for their organization" ON "public"."order_items" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."orders"
  WHERE (("orders"."id" = "order_items"."order_id") AND ("orders"."organization_id" = ( SELECT "users"."organization_id"
           FROM "public"."users"
          WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Users can update own organization receipt settings" ON "public"."receipt_settings" FOR UPDATE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can update server displays for their organization" ON "public"."server_displays" FOR UPDATE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can update tos_sessions" ON "public"."tos_sessions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "tos_sessions"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "tos_sessions"."organization_id")))));



CREATE POLICY "Users can view bell order displays in their organization" ON "public"."bos_displays" FOR SELECT USING (("organization_id" IN ( SELECT "bos_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can view device settings in their organization" ON "public"."device_settings" FOR SELECT USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can view kitchen displays in their organization" ON "public"."kitchen_displays" FOR SELECT USING (("organization_id" IN ( SELECT "kitchen_displays"."organization_id"
   FROM "public"."user_store_roles"
  WHERE ("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can view note templates for their organization" ON "public"."note_templates" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" = "note_templates"."organization_id")))));



CREATE POLICY "Users can view order items for their organization" ON "public"."order_items" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."orders"
  WHERE (("orders"."id" = "order_items"."order_id") AND ("orders"."organization_id" = ( SELECT "users"."organization_id"
           FROM "public"."users"
          WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Users can view organization coupons" ON "public"."coupons" FOR SELECT USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" IS NOT NULL)))));



CREATE POLICY "Users can view own organization receipt settings" ON "public"."receipt_settings" FOR SELECT USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can view server displays for their organization" ON "public"."server_displays" FOR SELECT USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can view their organization's POS settings" ON "public"."pos_settings" FOR SELECT USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Users can view their own deletion audit" ON "public"."account_deletion_audit" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view tos_sessions" ON "public"."tos_sessions" FOR SELECT TO "anon" USING (("active" = true));



ALTER TABLE "public"."account_deletion_audit" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "all_users_can_view_subscription_plans" ON "public"."subscription_plans" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));



CREATE POLICY "allow_insert_stores" ON "public"."stores" FOR INSERT WITH CHECK (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND ("organization_id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text"))))));



ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "authenticated_users_can_create_change_logs" ON "public"."change_logs" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));



CREATE POLICY "authenticated_users_can_view_change_logs" ON "public"."change_logs" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));



ALTER TABLE "public"."billing_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bos_displays" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ca_delete" ON "public"."category_availability" FOR DELETE USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "category_availability"."store_id") AND "public"."user_in_org"("s"."organization_id"))))));



CREATE POLICY "ca_insert" ON "public"."category_availability" FOR INSERT WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "category_availability"."store_id") AND "public"."user_in_org"("s"."organization_id"))))));



CREATE POLICY "ca_select" ON "public"."category_availability" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "category_availability"."store_id") AND "public"."user_in_org"("s"."organization_id"))))));



CREATE POLICY "ca_update" ON "public"."category_availability" FOR UPDATE USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "category_availability"."store_id") AND "public"."user_in_org"("s"."organization_id")))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "category_availability"."store_id") AND "public"."user_in_org"("s"."organization_id"))))));



ALTER TABLE "public"."cartons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."category_availability" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."change_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."coupons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_display_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_displays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dining_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."initialization_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."initialization_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kitchen_displays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."modified_order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."netvisor_products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."netvisor_refund_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."netvisor_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."netvisor_sync_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."note_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_commits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_restore_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_sequences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "organization_members_can_read_billing_history" ON "public"."billing_history" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "billing_history"."organization_id") AND (("users"."role")::"text" = 'owner'::"text")))) OR (EXISTS ( SELECT 1
   FROM ("public"."user_store_roles"
     JOIN "public"."stores" ON (("user_store_roles"."store_id" = "stores"."id")))
  WHERE (("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("stores"."organization_id" = "billing_history"."organization_id") AND ("user_store_roles"."role" = ANY (ARRAY['Admin'::"text", 'owner'::"text"])))))));



CREATE POLICY "organization_members_can_read_subscriptions" ON "public"."subscriptions" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "subscriptions"."organization_id") AND (("users"."role")::"text" = 'owner'::"text")))) OR (EXISTS ( SELECT 1
   FROM ("public"."user_store_roles"
     JOIN "public"."stores" ON (("user_store_roles"."store_id" = "stores"."id")))
  WHERE (("user_store_roles"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("stores"."organization_id" = "subscriptions"."organization_id") AND ("user_store_roles"."role" = ANY (ARRAY['Admin'::"text", 'owner'::"text"])))))));



CREATE POLICY "organization_owners_insert_users" ON "public"."users" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text")))));



ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "organizations_insert_authenticated" ON "public"."organizations" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));



CREATE POLICY "organizations_select_own" ON "public"."organizations" FOR SELECT USING (("id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" IS NOT NULL)))));



CREATE POLICY "organizations_update_owners_managers" ON "public"."organizations" FOR UPDATE USING ((("id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" IS NOT NULL)))) AND (("id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text")))) OR ("id" IN ( SELECT "s"."organization_id"
   FROM ("public"."stores" "s"
     JOIN "public"."user_store_roles" "usr" ON (("s"."id" = "usr"."store_id")))
  WHERE (("usr"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("usr"."role" = ANY (ARRAY['owner'::"text", 'manager'::"text"])) AND ("usr"."is_active" = true))))))) WITH CHECK ((("id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."organization_id" IS NOT NULL)))) AND (("id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text")))) OR ("id" IN ( SELECT "s"."organization_id"
   FROM ("public"."stores" "s"
     JOIN "public"."user_store_roles" "usr" ON (("s"."id" = "usr"."store_id")))
  WHERE (("usr"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("usr"."role" = ANY (ARRAY['owner'::"text", 'manager'::"text"])) AND ("usr"."is_active" = true)))))));



CREATE POLICY "pa_delete" ON "public"."product_availabilities" FOR DELETE USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "product_availabilities"."store_id") AND "public"."user_in_org"("s"."organization_id"))))));



CREATE POLICY "pa_insert" ON "public"."product_availabilities" FOR INSERT WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."stores" "s"
     JOIN "public"."products" "p" ON (("p"."id" = "product_availabilities"."product_id")))
  WHERE (("s"."id" = "product_availabilities"."store_id") AND ("p"."organization_id" = "s"."organization_id") AND "public"."user_in_org"("s"."organization_id"))))));



CREATE POLICY "pa_select" ON "public"."product_availabilities" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "product_availabilities"."store_id") AND "public"."user_in_org"("s"."organization_id"))))));



CREATE POLICY "pa_update" ON "public"."product_availabilities" FOR UPDATE USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."id" = "product_availabilities"."store_id") AND "public"."user_in_org"("s"."organization_id")))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."stores" "s"
     JOIN "public"."products" "p" ON (("p"."id" = "product_availabilities"."product_id")))
  WHERE (("s"."id" = "product_availabilities"."store_id") AND ("p"."organization_id" = "s"."organization_id") AND "public"."user_in_org"("s"."organization_id"))))));



ALTER TABLE "public"."payment_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pos_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "printer post" ON "public"."printers" FOR INSERT WITH CHECK (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND ("organization_id" IN ( SELECT "s"."organization_id"
   FROM ("public"."user_store_roles" "usr"
     JOIN "public"."stores" "s" ON (("s"."id" = "usr"."store_id")))
  WHERE ("usr"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



ALTER TABLE "public"."printers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_availabilities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_delete" ON "public"."products" FOR DELETE USING (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



CREATE POLICY "products_insert" ON "public"."products" FOR INSERT WITH CHECK (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



CREATE POLICY "products_select" ON "public"."products" FOR SELECT USING (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



CREATE POLICY "products_update" ON "public"."products" FOR UPDATE USING (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text"))) WITH CHECK (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



ALTER TABLE "public"."receipt_number_sequences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."receipt_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "safe_user_store_roles_delete" ON "public"."user_store_roles" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM ("public"."users" "u"
     JOIN "public"."stores" "s" ON (("u"."organization_id" = "s"."organization_id")))
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text") AND ("s"."id" = "user_store_roles"."store_id")))));



CREATE POLICY "safe_user_store_roles_insert" ON "public"."user_store_roles" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."users" "u"
     JOIN "public"."stores" "s" ON (("u"."organization_id" = "s"."organization_id")))
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text") AND ("s"."id" = "user_store_roles"."store_id")))));



CREATE POLICY "safe_user_store_roles_select" ON "public"."user_store_roles" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM ("public"."users" "u"
     JOIN "public"."stores" "s" ON (("u"."organization_id" = "s"."organization_id")))
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text") AND ("s"."id" = "user_store_roles"."store_id")))) OR ("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("email" = ( SELECT "auth"."email"() AS "email"))));



CREATE POLICY "safe_user_store_roles_update" ON "public"."user_store_roles" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM ("public"."users" "u"
     JOIN "public"."stores" "s" ON (("u"."organization_id" = "s"."organization_id")))
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role")::"text" = 'owner'::"text") AND ("s"."id" = "user_store_roles"."store_id")))));



ALTER TABLE "public"."server_displays" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "service_role_all_organizations" ON "public"."organizations" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_stores" ON "public"."stores" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_users" ON "public"."users" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_bypass_audit_logs" ON "public"."audit_logs" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_bell_order_displays" ON "public"."bos_displays" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_billing_history" ON "public"."billing_history" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_cartons" ON "public"."cartons" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_categories" ON "public"."categories" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_change_logs" ON "public"."change_logs" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_dining_options" ON "public"."dining_options" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_inventory" ON "public"."inventory" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_inventory_history" ON "public"."inventory_history" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_kitchen_displays" ON "public"."kitchen_displays" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_modified_order_items" ON "public"."modified_order_items" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_netvisor_products" ON "public"."netvisor_products" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_netvisor_settings" ON "public"."netvisor_settings" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_netvisor_sync_history" ON "public"."netvisor_sync_history" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_order_items" ON "public"."order_items" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_payment_types" ON "public"."payment_types" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_products" ON "public"."products" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_receipt_settings" ON "public"."receipt_settings" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_subscription_plans" ON "public"."subscription_plans" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_subscriptions" ON "public"."subscriptions" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_tax_settings" ON "public"."tax_settings" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_bypass_transaction_modifications" ON "public"."transaction_modifications" USING ((( SELECT "current_setting"('role'::"text", true) AS "current_setting") = 'service_role'::"text"));



CREATE POLICY "service_role_full_access" ON "public"."orders" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."stores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stores_delete" ON "public"."stores" FOR DELETE USING (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



CREATE POLICY "stores_insert" ON "public"."stores" FOR INSERT WITH CHECK (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



CREATE POLICY "stores_select" ON "public"."stores" FOR SELECT USING (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



CREATE POLICY "stores_select_with_registration_exception" ON "public"."stores" FOR SELECT USING ((((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND ("organization_id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = ( SELECT "auth"."uid"() AS "uid"))))) OR (( SELECT "auth"."uid"() AS "uid") IS NULL) OR (( SELECT "auth"."uid"() AS "uid") IS NOT NULL)));



CREATE POLICY "stores_update" ON "public"."stores" FOR UPDATE USING (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text"))) WITH CHECK (("public"."user_in_org"("organization_id") OR (( SELECT "auth"."role"() AS "role") = 'service_role'::"text")));



ALTER TABLE "public"."subscription_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."table_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "table_sessions_delete_policy" ON "public"."table_sessions" FOR DELETE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "table_sessions_insert_policy" ON "public"."table_sessions" FOR INSERT WITH CHECK (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "table_sessions_select_policy" ON "public"."table_sessions" FOR SELECT USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "table_sessions_update_policy" ON "public"."table_sessions" FOR UPDATE USING (("organization_id" IN ( SELECT "users"."organization_id"
   FROM "public"."users"
  WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")))));



ALTER TABLE "public"."tax_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tos_displays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tos_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transaction_modifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_store_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_basic_select" ON "public"."users" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));



CREATE POLICY "users_can_create_org_order_commits" ON "public"."order_commits" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."orders" "o"
     JOIN "public"."users" "u" ON (("u"."organization_id" = "o"."organization_id")))
  WHERE (("o"."id" = "order_commits"."order_id") AND ("u"."id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "users_can_create_org_orders" ON "public"."orders" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "orders"."organization_id")))));



CREATE POLICY "users_can_create_org_restore_requests" ON "public"."order_restore_requests" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "order_restore_requests"."organization_id")))));



CREATE POLICY "users_can_create_own_audit_logs" ON "public"."audit_logs" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "users_can_delete_org_initialization_history" ON "public"."initialization_history" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_history"."organization_id")))));



CREATE POLICY "users_can_delete_org_initialization_templates" ON "public"."initialization_templates" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_templates"."organization_id")))));



CREATE POLICY "users_can_delete_org_orders" ON "public"."orders" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "orders"."organization_id")))));



CREATE POLICY "users_can_insert_org_initialization_history" ON "public"."initialization_history" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_history"."organization_id")))));



CREATE POLICY "users_can_insert_org_initialization_templates" ON "public"."initialization_templates" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_templates"."organization_id")))));



CREATE POLICY "users_can_manage_org_bell_order_displays" ON "public"."bos_displays" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "bos_displays"."organization_id")))));



CREATE POLICY "users_can_manage_org_cartons" ON "public"."cartons" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "cartons"."organization_id")))));



CREATE POLICY "users_can_manage_org_categories" ON "public"."categories" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "categories"."organization_id")))));



CREATE POLICY "users_can_manage_org_dining_options" ON "public"."dining_options" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "dining_options"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "dining_options"."organization_id")))));



CREATE POLICY "users_can_manage_org_inventory" ON "public"."inventory" USING ((EXISTS ( SELECT 1
   FROM ("public"."users"
     JOIN "public"."stores" ON (("stores"."organization_id" = "users"."organization_id")))
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("stores"."id" = "inventory"."store_id")))));



CREATE POLICY "users_can_manage_org_kitchen_displays" ON "public"."kitchen_displays" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "kitchen_displays"."organization_id")))));



CREATE POLICY "users_can_manage_org_modified_order_items" ON "public"."modified_order_items" USING ((EXISTS ( SELECT 1
   FROM (("public"."orders"
     JOIN "public"."stores" ON (("stores"."id" = "orders"."store_id")))
     JOIN "public"."users" ON (("users"."organization_id" = "stores"."organization_id")))
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("orders"."id" = "modified_order_items"."order_id")))));



CREATE POLICY "users_can_manage_org_netvisor_products" ON "public"."netvisor_products" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_products"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_products"."organization_id")))));



CREATE POLICY "users_can_manage_org_netvisor_refund_history" ON "public"."netvisor_refund_history" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_refund_history"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_refund_history"."organization_id")))));



CREATE POLICY "users_can_manage_org_netvisor_settings" ON "public"."netvisor_settings" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_settings"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_settings"."organization_id")))));



CREATE POLICY "users_can_manage_org_netvisor_sync_history" ON "public"."netvisor_sync_history" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_sync_history"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "netvisor_sync_history"."organization_id")))));



CREATE POLICY "users_can_manage_org_order_items" ON "public"."order_items" USING ((EXISTS ( SELECT 1
   FROM ("public"."orders"
     JOIN "public"."users" ON (("users"."organization_id" = "orders"."organization_id")))
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("orders"."id" = "order_items"."order_id")))));



CREATE POLICY "users_can_manage_org_payment_types" ON "public"."payment_types" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "payment_types"."organization_id")))));



CREATE POLICY "users_can_manage_org_products" ON "public"."products" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "products"."organization_id")))));



CREATE POLICY "users_can_manage_org_receipt_settings" ON "public"."receipt_settings" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "receipt_settings"."organization_id")))));



CREATE POLICY "users_can_manage_org_tax_settings" ON "public"."tax_settings" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "tax_settings"."organization_id")))));



CREATE POLICY "users_can_manage_org_tos_displays" ON "public"."tos_displays" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "tos_displays"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "tos_displays"."organization_id")))));



CREATE POLICY "users_can_manage_org_transaction_modifications" ON "public"."transaction_modifications" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "transaction_modifications"."organization_id")))));



CREATE POLICY "users_can_update_org_initialization_history" ON "public"."initialization_history" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_history"."organization_id")))));



CREATE POLICY "users_can_update_org_initialization_templates" ON "public"."initialization_templates" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_templates"."organization_id")))));



CREATE POLICY "users_can_update_org_orders" ON "public"."orders" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "orders"."organization_id")))));



CREATE POLICY "users_can_update_org_restore_requests" ON "public"."order_restore_requests" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "order_restore_requests"."organization_id")))));



CREATE POLICY "users_can_view_org_initialization_history" ON "public"."initialization_history" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_history"."organization_id")))));



CREATE POLICY "users_can_view_org_initialization_templates" ON "public"."initialization_templates" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "initialization_templates"."organization_id")))));



CREATE POLICY "users_can_view_org_inventory_history" ON "public"."inventory_history" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "inventory_history"."organization_id")))));



CREATE POLICY "users_can_view_org_order_commits" ON "public"."order_commits" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."orders" "o"
     JOIN "public"."users" "u" ON (("u"."organization_id" = "o"."organization_id")))
  WHERE (("o"."id" = "order_commits"."order_id") AND ("u"."id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "users_can_view_org_orders" ON "public"."orders" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "orders"."organization_id")))));



CREATE POLICY "users_can_view_org_restore_requests" ON "public"."order_restore_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."organization_id" = "order_restore_requests"."organization_id")))));



CREATE POLICY "users_can_view_own_audit_logs" ON "public"."audit_logs" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "users_delete_organization_stores" ON "public"."stores" FOR DELETE USING (("organization_id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "users_insert_own_record" ON "public"."users" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "users_update_organization_stores" ON "public"."stores" FOR UPDATE USING (("organization_id" IN ( SELECT "u"."organization_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "users_update_own_record" ON "public"."users" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Allow org members to delete logo images" ON "storage"."objects" FOR DELETE TO "authenticated" USING ((("bucket_id" = 'logo_images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()))));



CREATE POLICY "Allow org members to delete product images" ON "storage"."objects" FOR DELETE TO "authenticated" USING ((("bucket_id" = 'product-images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()))));



CREATE POLICY "Allow org members to update logo images" ON "storage"."objects" FOR UPDATE TO "authenticated" USING ((("bucket_id" = 'logo_images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()))));



CREATE POLICY "Allow org members to update product images" ON "storage"."objects" FOR UPDATE TO "authenticated" USING ((("bucket_id" = 'product-images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()))));



CREATE POLICY "Allow org members to upload logo images" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK ((("bucket_id" = 'logo_images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()))));



CREATE POLICY "Allow org members to upload product images" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK ((("bucket_id" = 'product-images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()))));



CREATE POLICY "Allow org members to view logo images" ON "storage"."objects" FOR SELECT TO "authenticated" USING ((("bucket_id" = 'logo_images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()) OR ("name" !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'::"text"))));



CREATE POLICY "Allow org members to view product images" ON "storage"."objects" FOR SELECT TO "authenticated" USING ((("bucket_id" = 'product-images'::"text") AND (("auth"."role"() = 'service_role'::"text") OR ("public"."extract_org_id_from_path"("name") = "public"."get_user_organization_id"()) OR ("name" !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'::"text"))));



CREATE POLICY "Receipt logo restricted access" ON "storage"."objects" FOR SELECT TO "authenticated", "anon" USING ((("bucket_id" = 'logo_images'::"text") AND ("name" ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/logo-[0-9]+-[a-z0-9]+\.(jpg|jpeg|png|webp)$'::"text")));



CREATE POLICY "Temp - Allow all authenticated access to product-images" ON "storage"."objects" FOR SELECT TO "authenticated" USING (("bucket_id" = 'product-images'::"text"));



CREATE POLICY "Temp - Allow all authenticated uploads to product-images" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK (("bucket_id" = 'product-images'::"text"));



CREATE POLICY "Temp-Allow all authenticated deletes to logo_image 1jul18s_0" ON "storage"."objects" FOR DELETE TO "authenticated" USING (("bucket_id" = 'logo_images'::"text"));



CREATE POLICY "Temp-Allow all authenticated select to logo_image 1jul18s_0" ON "storage"."objects" FOR SELECT TO "authenticated" USING (("bucket_id" = 'logo_images'::"text"));



CREATE POLICY "Temp-Allow all authenticated uploads to logo_image 1jul18s_0" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK (("bucket_id" = 'logo_images'::"text"));



ALTER TABLE "storage"."buckets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."buckets_analytics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."buckets_vectors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."migrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."prefixes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."s3_multipart_uploads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."s3_multipart_uploads_parts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."vector_indexes" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "auth" TO "anon";
GRANT USAGE ON SCHEMA "auth" TO "authenticated";
GRANT USAGE ON SCHEMA "auth" TO "service_role";
GRANT ALL ON SCHEMA "auth" TO "supabase_auth_admin";
GRANT ALL ON SCHEMA "auth" TO "dashboard_user";
GRANT USAGE ON SCHEMA "auth" TO "postgres";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT USAGE ON SCHEMA "storage" TO "postgres" WITH GRANT OPTION;
GRANT USAGE ON SCHEMA "storage" TO "anon";
GRANT USAGE ON SCHEMA "storage" TO "authenticated";
GRANT USAGE ON SCHEMA "storage" TO "service_role";
GRANT ALL ON SCHEMA "storage" TO "supabase_storage_admin";
GRANT ALL ON SCHEMA "storage" TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."email"() TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."jwt"() TO "postgres";
GRANT ALL ON FUNCTION "auth"."jwt"() TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."role"() TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."uid"() TO "dashboard_user";



GRANT ALL ON FUNCTION "public"."audit_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."audit_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."audit_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."broadcast_new_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."broadcast_new_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."broadcast_new_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."broadcast_order_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."broadcast_order_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."broadcast_order_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."change_log_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."change_log_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."change_log_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_admin_role_for_storage"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_admin_role_for_storage"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_admin_role_for_storage"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_kds_triggers"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_kds_triggers"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_kds_triggers"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_upload_organization_path"("file_path" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_upload_organization_path"("file_path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_upload_organization_path"("file_path" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_user_organization_storage_access"("file_path" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_user_organization_storage_access"("file_path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_user_organization_storage_access"("file_path" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_audit_logs"("days_to_keep" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_audit_logs"("days_to_keep" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_audit_logs"("days_to_keep" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_cds_carts"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_cds_carts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_cds_carts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_cds_sessions"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_cds_sessions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_cds_sessions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_sessions"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_sessions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_sessions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_kds_test_data"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_kds_test_data"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_kds_test_data"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_old_cds_sessions"("older_than_hours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_old_cds_sessions"("older_than_hours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_old_cds_sessions"("older_than_hours" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_stale_persistent_sessions"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_stale_persistent_sessions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_stale_persistent_sessions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_synced_change_logs"("days_to_keep" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_synced_change_logs"("days_to_keep" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_synced_change_logs"("days_to_keep" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_cds_order"("p_display_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_cds_order"("p_display_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_cds_order"("p_display_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_order_and_cleanup"("p_display_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_order_and_cleanup"("p_display_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_order_and_cleanup"("p_display_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."connect_to_persistent_session"("p_session_token" "text", "p_device_id" "text", "p_device_token" "text", "p_ip_address" "inet", "p_user_agent" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."connect_to_persistent_session"("p_session_token" "text", "p_device_id" "text", "p_device_token" "text", "p_ip_address" "inet", "p_user_agent" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."connect_to_persistent_session"("p_session_token" "text", "p_device_id" "text", "p_device_token" "text", "p_ip_address" "inet", "p_user_agent" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_persistent_session"("p_organization_id" "uuid", "p_store_id" "uuid", "p_table_number" integer, "p_device_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_persistent_session"("p_organization_id" "uuid", "p_store_id" "uuid", "p_table_number" integer, "p_device_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_persistent_session"("p_organization_id" "uuid", "p_store_id" "uuid", "p_table_number" integer, "p_device_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_test_user_with_org"("user_email" "text", "user_name" "text", "org_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_test_user_with_org"("user_email" "text", "user_name" "text", "org_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_test_user_with_org"("user_email" "text", "user_name" "text", "org_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cross_tab_insert_product"("p_source_tab_id" "uuid", "p_target_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."cross_tab_insert_product"("p_source_tab_id" "uuid", "p_target_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cross_tab_insert_product"("p_source_tab_id" "uuid", "p_target_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."disconnect_from_persistent_session"("p_session_id" "uuid", "p_device_id" "text", "p_is_manual" boolean, "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."disconnect_from_persistent_session"("p_session_id" "uuid", "p_device_id" "text", "p_is_manual" boolean, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."disconnect_from_persistent_session"("p_session_id" "uuid", "p_device_id" "text", "p_is_manual" boolean, "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."exec_sql"("sql" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."exec_sql"("sql" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."exec_sql"("sql" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."extract_org_id_from_path"("file_path" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."extract_org_id_from_path"("file_path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."extract_org_id_from_path"("file_path" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."fix_user_profile"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."fix_user_profile"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fix_user_profile"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fix_user_profile"("p_user_id" "uuid", "p_user_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."fix_user_profile"("p_user_id" "uuid", "p_user_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fix_user_profile"("p_user_id" "uuid", "p_user_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_cds_token"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_cds_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_cds_token"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_order_number"("store_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_order_number"("store_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_order_number"("store_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_order_number"("p_store_id" "uuid", "p_timezone" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_order_number"("p_store_id" "uuid", "p_timezone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_order_number"("p_store_id" "uuid", "p_timezone" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_receipt_number"("p_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_receipt_number"("p_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_receipt_number"("p_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_session_token"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_session_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_session_token"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_active_self_order_displays"("p_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_active_self_order_displays"("p_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_active_self_order_displays"("p_store_id" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_available_categories"("p_organization_id" "uuid", "p_current_time_utc" time without time zone, "p_current_dow" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_available_categories"("p_organization_id" "uuid", "p_current_time_utc" time without time zone, "p_current_dow" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_available_categories"("p_organization_id" "uuid", "p_current_time_utc" time without time zone, "p_current_dow" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_cds_cart_by_token"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_cds_cart_by_token"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cds_cart_by_token"("p_token" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_sequence"("p_store_id" "uuid", "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_sequence"("p_store_id" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_sequence"("p_store_id" "uuid", "p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_organization_business_id"("org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_organization_business_id"("org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_organization_business_id"("org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_restore_status"("p_restore_request_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_restore_status"("p_restore_request_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_restore_status"("p_restore_request_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_schema_info"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_schema_info"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_schema_info"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_session_for_cds"("session_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_session_for_cds"("session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_session_for_cds"("session_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_organization_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_organization_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_organization_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_organizations"("user_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_organizations"("user_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_organizations"("user_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_stores"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_stores"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_stores"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."insert_product_at_position"("p_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."insert_product_at_position"("p_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."insert_product_at_position"("p_tab_id" "uuid", "p_product_id" "uuid", "p_insert_position" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."is_cds_token_valid"("token_input" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_cds_token_valid"("token_input" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_cds_token_valid"("token_input" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_owner_or_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_owner_or_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_owner_or_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."normalize_display_orders"("p_tab_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."normalize_display_orders"("p_tab_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_display_orders"("p_tab_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_category_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_category_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_category_changes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_cds_session_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_cds_session_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_cds_session_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_cds_session_change_completed_migration"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_cds_session_change_completed_migration"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_cds_session_change_completed_migration"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_cds_session_change_with_store_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_cds_session_change_with_store_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_cds_session_change_with_store_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_kds_order_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_kds_order_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_kds_order_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_product_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_product_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_product_changes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_new_user_login"("p_user_id" "uuid", "p_user_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."process_new_user_login"("p_user_id" "uuid", "p_user_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_new_user_login"("p_user_id" "uuid", "p_user_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_order_restore"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_order_restore"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_order_restore"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_order_totals"() TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_order_totals"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_order_totals"() TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_order_sequence"("p_store_id" "uuid", "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_order_sequence"("p_store_id" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_order_sequence"("p_store_id" "uuid", "p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."restore_order"("p_order_id" "uuid", "p_store_id" "uuid", "p_requested_by" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."restore_order"("p_order_id" "uuid", "p_store_id" "uuid", "p_requested_by" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_order"("p_order_id" "uuid", "p_store_id" "uuid", "p_requested_by" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_get_tos_display"("p_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_get_tos_display"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_get_tos_display"("p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_category_grid_number"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_category_grid_number"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_category_grid_number"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_product_grid_number"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_product_grid_number"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_product_grid_number"() TO "service_role";



GRANT ALL ON FUNCTION "public"."setup_organization_clean"("p_user_id" "uuid", "p_user_email" "text", "p_org_name" "text", "p_org_slug" "text", "p_store_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."setup_organization_clean"("p_user_id" "uuid", "p_user_email" "text", "p_org_name" "text", "p_org_slug" "text", "p_store_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."setup_organization_clean"("p_user_id" "uuid", "p_user_email" "text", "p_org_name" "text", "p_org_slug" "text", "p_store_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."simple_handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."simple_handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."simple_handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."start_new_order_session"("p_display_id" "uuid", "p_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_new_order_session"("p_display_id" "uuid", "p_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_new_order_session"("p_display_id" "uuid", "p_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."swap_product_positions"("p_tab_id" "uuid", "product_a_id" "uuid", "product_b_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."swap_product_positions"("p_tab_id" "uuid", "product_a_id" "uuid", "product_b_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."swap_product_positions"("p_tab_id" "uuid", "product_a_id" "uuid", "product_b_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."test_cds_session_triggers"() TO "anon";
GRANT ALL ON FUNCTION "public"."test_cds_session_triggers"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."test_cds_session_triggers"() TO "service_role";



GRANT ALL ON FUNCTION "public"."test_cds_triggers"() TO "anon";
GRANT ALL ON FUNCTION "public"."test_cds_triggers"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."test_cds_triggers"() TO "service_role";



GRANT ALL ON FUNCTION "public"."test_kds_triggers"("test_store_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."test_kds_triggers"("test_store_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."test_kds_triggers"("test_store_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."test_kds_triggers"("test_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."test_kds_triggers"("test_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."test_kds_triggers"("test_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."test_order_restore"("test_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."test_order_restore"("test_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."test_order_restore"("test_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_coupons_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_coupons_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_coupons_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_device_categories_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_device_categories_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_device_categories_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_inventory_on_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_inventory_on_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_inventory_on_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_order_sequences_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_order_sequences_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_order_sequences_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_receipt_number_sequences_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_receipt_number_sequences_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_receipt_number_sequences_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_self_order_display_last_seen"("p_device_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_self_order_display_last_seen"("p_device_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_self_order_display_last_seen"("p_device_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_self_order_display_settings_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_self_order_display_settings_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_self_order_display_settings_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_self_order_displays_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_self_order_displays_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_self_order_displays_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_session_heartbeat"("p_session_id" "uuid", "p_device_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_session_heartbeat"("p_session_id" "uuid", "p_device_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_session_heartbeat"("p_session_id" "uuid", "p_device_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_tab_orders"("org_id" "uuid", "tab_order_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_tab_orders"("org_id" "uuid", "tab_order_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_tab_orders"("org_id" "uuid", "tab_order_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_table_sessions_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_table_sessions_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_table_sessions_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_tos_sessions_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_tos_sessions_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_tos_sessions_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_cds_cart"("p_token" "text", "p_organization_id" "uuid", "p_store_id" "uuid", "p_items" "jsonb", "p_totals" "jsonb", "p_table_number" integer, "p_dining_option" "text", "p_call_number" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_cds_cart"("p_token" "text", "p_organization_id" "uuid", "p_store_id" "uuid", "p_items" "jsonb", "p_totals" "jsonb", "p_table_number" integer, "p_dining_option" "text", "p_call_number" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_cds_cart"("p_token" "text", "p_organization_id" "uuid", "p_store_id" "uuid", "p_items" "jsonb", "p_totals" "jsonb", "p_table_number" integer, "p_dining_option" "text", "p_call_number" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."user_belongs_to_org"("target_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_belongs_to_org"("target_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_belongs_to_org"("target_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_belongs_to_org"("user_uuid" "uuid", "org_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_belongs_to_org"("user_uuid" "uuid", "org_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_belongs_to_org"("user_uuid" "uuid", "org_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_can_access_store"("target_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_can_access_store"("target_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_can_access_store"("target_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_has_org_role"("user_uuid" "uuid", "check_role" "text", "org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_has_org_role"("user_uuid" "uuid", "check_role" "text", "org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_has_org_role"("user_uuid" "uuid", "check_role" "text", "org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_has_store_access"("store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_has_store_access"("store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_has_store_access"("store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_has_store_role"("p_user_id" "uuid", "p_store_id" "uuid", "p_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."user_has_store_role"("p_user_id" "uuid", "p_store_id" "uuid", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_has_store_role"("p_user_id" "uuid", "p_store_id" "uuid", "p_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_in_org"("_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_in_org"("_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_in_org"("_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."user_is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_bos_device"("device_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."validate_bos_device"("device_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_bos_device"("device_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_role_assignment_scope"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_role_assignment_scope"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_role_assignment_scope"() TO "service_role";



GRANT ALL ON TABLE "auth"."audit_log_entries" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."audit_log_entries" TO "postgres";
GRANT SELECT ON TABLE "auth"."audit_log_entries" TO "postgres" WITH GRANT OPTION;



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."flow_state" TO "postgres";
GRANT SELECT ON TABLE "auth"."flow_state" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."flow_state" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."identities" TO "postgres";
GRANT SELECT ON TABLE "auth"."identities" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."identities" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."instances" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."instances" TO "postgres";
GRANT SELECT ON TABLE "auth"."instances" TO "postgres" WITH GRANT OPTION;



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."mfa_amr_claims" TO "postgres";
GRANT SELECT ON TABLE "auth"."mfa_amr_claims" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."mfa_amr_claims" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."mfa_challenges" TO "postgres";
GRANT SELECT ON TABLE "auth"."mfa_challenges" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."mfa_challenges" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."mfa_factors" TO "postgres";
GRANT SELECT ON TABLE "auth"."mfa_factors" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."mfa_factors" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."oauth_authorizations" TO "postgres";
GRANT ALL ON TABLE "auth"."oauth_authorizations" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."oauth_clients" TO "postgres";
GRANT ALL ON TABLE "auth"."oauth_clients" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."oauth_consents" TO "postgres";
GRANT ALL ON TABLE "auth"."oauth_consents" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."one_time_tokens" TO "postgres";
GRANT SELECT ON TABLE "auth"."one_time_tokens" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."one_time_tokens" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."refresh_tokens" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."refresh_tokens" TO "postgres";
GRANT SELECT ON TABLE "auth"."refresh_tokens" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON SEQUENCE "auth"."refresh_tokens_id_seq" TO "dashboard_user";
GRANT ALL ON SEQUENCE "auth"."refresh_tokens_id_seq" TO "postgres";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."saml_providers" TO "postgres";
GRANT SELECT ON TABLE "auth"."saml_providers" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."saml_providers" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."saml_relay_states" TO "postgres";
GRANT SELECT ON TABLE "auth"."saml_relay_states" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."saml_relay_states" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."sessions" TO "postgres";
GRANT SELECT ON TABLE "auth"."sessions" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."sessions" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."sso_domains" TO "postgres";
GRANT SELECT ON TABLE "auth"."sso_domains" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."sso_domains" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."sso_providers" TO "postgres";
GRANT SELECT ON TABLE "auth"."sso_providers" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."sso_providers" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."users" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."users" TO "postgres";
GRANT SELECT ON TABLE "auth"."users" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "public"."account_deletion_audit" TO "anon";
GRANT ALL ON TABLE "public"."account_deletion_audit" TO "authenticated";
GRANT ALL ON TABLE "public"."account_deletion_audit" TO "service_role";



GRANT ALL ON TABLE "public"."audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_logs" TO "service_role";



GRANT ALL ON TABLE "public"."billing_history" TO "anon";
GRANT ALL ON TABLE "public"."billing_history" TO "authenticated";
GRANT ALL ON TABLE "public"."billing_history" TO "service_role";



GRANT ALL ON TABLE "public"."bos_displays" TO "anon";
GRANT ALL ON TABLE "public"."bos_displays" TO "authenticated";
GRANT ALL ON TABLE "public"."bos_displays" TO "service_role";



GRANT ALL ON TABLE "public"."cartons" TO "anon";
GRANT ALL ON TABLE "public"."cartons" TO "authenticated";
GRANT ALL ON TABLE "public"."cartons" TO "service_role";



GRANT ALL ON TABLE "public"."category_availability" TO "anon";
GRANT ALL ON TABLE "public"."category_availability" TO "authenticated";
GRANT ALL ON TABLE "public"."category_availability" TO "service_role";



GRANT ALL ON TABLE "public"."change_logs" TO "anon";
GRANT ALL ON TABLE "public"."change_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."change_logs" TO "service_role";



GRANT ALL ON TABLE "public"."coupons" TO "anon";
GRANT ALL ON TABLE "public"."coupons" TO "authenticated";
GRANT ALL ON TABLE "public"."coupons" TO "service_role";



GRANT ALL ON TABLE "public"."customer_display_sessions" TO "anon";
GRANT ALL ON TABLE "public"."customer_display_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_display_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."customer_displays" TO "anon";
GRANT ALL ON TABLE "public"."customer_displays" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_displays" TO "service_role";



GRANT ALL ON TABLE "public"."device_settings" TO "anon";
GRANT ALL ON TABLE "public"."device_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."device_settings" TO "service_role";



GRANT ALL ON TABLE "public"."dining_options" TO "anon";
GRANT ALL ON TABLE "public"."dining_options" TO "authenticated";
GRANT ALL ON TABLE "public"."dining_options" TO "service_role";



GRANT ALL ON TABLE "public"."initialization_history" TO "anon";
GRANT ALL ON TABLE "public"."initialization_history" TO "authenticated";
GRANT ALL ON TABLE "public"."initialization_history" TO "service_role";



GRANT ALL ON TABLE "public"."initialization_templates" TO "anon";
GRANT ALL ON TABLE "public"."initialization_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."initialization_templates" TO "service_role";



GRANT ALL ON TABLE "public"."inventory" TO "anon";
GRANT ALL ON TABLE "public"."inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_history" TO "anon";
GRANT ALL ON TABLE "public"."inventory_history" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_history" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen_displays" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_displays" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_displays" TO "service_role";



GRANT ALL ON TABLE "public"."modified_order_items" TO "anon";
GRANT ALL ON TABLE "public"."modified_order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."modified_order_items" TO "service_role";



GRANT ALL ON TABLE "public"."netvisor_products" TO "anon";
GRANT ALL ON TABLE "public"."netvisor_products" TO "authenticated";
GRANT ALL ON TABLE "public"."netvisor_products" TO "service_role";



GRANT ALL ON TABLE "public"."netvisor_refund_history" TO "anon";
GRANT ALL ON TABLE "public"."netvisor_refund_history" TO "authenticated";
GRANT ALL ON TABLE "public"."netvisor_refund_history" TO "service_role";



GRANT ALL ON TABLE "public"."netvisor_settings" TO "anon";
GRANT ALL ON TABLE "public"."netvisor_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."netvisor_settings" TO "service_role";



GRANT ALL ON TABLE "public"."netvisor_sync_history" TO "anon";
GRANT ALL ON TABLE "public"."netvisor_sync_history" TO "authenticated";
GRANT ALL ON TABLE "public"."netvisor_sync_history" TO "service_role";



GRANT ALL ON TABLE "public"."note_templates" TO "anon";
GRANT ALL ON TABLE "public"."note_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."note_templates" TO "service_role";



GRANT ALL ON TABLE "public"."order_commits" TO "anon";
GRANT ALL ON TABLE "public"."order_commits" TO "authenticated";
GRANT ALL ON TABLE "public"."order_commits" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT ALL ON TABLE "public"."order_restore_requests" TO "anon";
GRANT ALL ON TABLE "public"."order_restore_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."order_restore_requests" TO "service_role";



GRANT ALL ON TABLE "public"."order_sequences" TO "anon";
GRANT ALL ON TABLE "public"."order_sequences" TO "authenticated";
GRANT ALL ON TABLE "public"."order_sequences" TO "service_role";



GRANT ALL ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";
GRANT ALL ON TABLE "public"."organizations" TO PUBLIC;



GRANT ALL ON TABLE "public"."payment_types" TO "anon";
GRANT ALL ON TABLE "public"."payment_types" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_types" TO "service_role";



GRANT ALL ON TABLE "public"."pos_settings" TO "anon";
GRANT ALL ON TABLE "public"."pos_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."pos_settings" TO "service_role";



GRANT ALL ON TABLE "public"."printers" TO "anon";
GRANT ALL ON TABLE "public"."printers" TO "authenticated";
GRANT ALL ON TABLE "public"."printers" TO "service_role";



GRANT ALL ON SEQUENCE "public"."printers_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."printers_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."printers_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."product_availabilities" TO "anon";
GRANT ALL ON TABLE "public"."product_availabilities" TO "authenticated";
GRANT ALL ON TABLE "public"."product_availabilities" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."receipt_number_sequences" TO "anon";
GRANT ALL ON TABLE "public"."receipt_number_sequences" TO "authenticated";
GRANT ALL ON TABLE "public"."receipt_number_sequences" TO "service_role";



GRANT ALL ON TABLE "public"."receipt_settings" TO "anon";
GRANT ALL ON TABLE "public"."receipt_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."receipt_settings" TO "service_role";



GRANT ALL ON TABLE "public"."server_displays" TO "anon";
GRANT ALL ON TABLE "public"."server_displays" TO "authenticated";
GRANT ALL ON TABLE "public"."server_displays" TO "service_role";



GRANT ALL ON TABLE "public"."stores" TO "anon";
GRANT ALL ON TABLE "public"."stores" TO "authenticated";
GRANT ALL ON TABLE "public"."stores" TO "service_role";
GRANT ALL ON TABLE "public"."stores" TO PUBLIC;



GRANT ALL ON TABLE "public"."subscription_plans" TO "anon";
GRANT ALL ON TABLE "public"."subscription_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_plans" TO "service_role";



GRANT ALL ON TABLE "public"."subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."table_sessions" TO "anon";
GRANT ALL ON TABLE "public"."table_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."table_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."tax_settings" TO "anon";
GRANT ALL ON TABLE "public"."tax_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."tax_settings" TO "service_role";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."tos_displays" TO "anon";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."tos_displays" TO "authenticated";
GRANT ALL ON TABLE "public"."tos_displays" TO "service_role";



GRANT ALL ON TABLE "public"."tos_sessions" TO "anon";
GRANT ALL ON TABLE "public"."tos_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."tos_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."transaction_modifications" TO "anon";
GRANT ALL ON TABLE "public"."transaction_modifications" TO "authenticated";
GRANT ALL ON TABLE "public"."transaction_modifications" TO "service_role";



GRANT ALL ON TABLE "public"."user_store_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_store_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_store_roles" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";
GRANT ALL ON TABLE "public"."users" TO PUBLIC;



REVOKE ALL ON TABLE "storage"."buckets" FROM "supabase_storage_admin";
GRANT ALL ON TABLE "storage"."buckets" TO "supabase_storage_admin" WITH GRANT OPTION;
GRANT ALL ON TABLE "storage"."buckets" TO "anon";
GRANT ALL ON TABLE "storage"."buckets" TO "authenticated";
GRANT ALL ON TABLE "storage"."buckets" TO "service_role";
GRANT ALL ON TABLE "storage"."buckets" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "storage"."buckets_analytics" TO "service_role";
GRANT ALL ON TABLE "storage"."buckets_analytics" TO "authenticated";
GRANT ALL ON TABLE "storage"."buckets_analytics" TO "anon";



GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "service_role";
GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "authenticated";
GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "anon";



REVOKE ALL ON TABLE "storage"."objects" FROM "supabase_storage_admin";
GRANT ALL ON TABLE "storage"."objects" TO "supabase_storage_admin" WITH GRANT OPTION;
GRANT ALL ON TABLE "storage"."objects" TO "anon";
GRANT ALL ON TABLE "storage"."objects" TO "authenticated";
GRANT ALL ON TABLE "storage"."objects" TO "service_role";
GRANT ALL ON TABLE "storage"."objects" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "storage"."prefixes" TO "service_role";
GRANT ALL ON TABLE "storage"."prefixes" TO "authenticated";
GRANT ALL ON TABLE "storage"."prefixes" TO "anon";



GRANT ALL ON TABLE "storage"."s3_multipart_uploads" TO "service_role";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads" TO "authenticated";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads" TO "anon";



GRANT ALL ON TABLE "storage"."s3_multipart_uploads_parts" TO "service_role";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads_parts" TO "authenticated";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads_parts" TO "anon";



GRANT SELECT ON TABLE "storage"."vector_indexes" TO "service_role";
GRANT SELECT ON TABLE "storage"."vector_indexes" TO "authenticated";
GRANT SELECT ON TABLE "storage"."vector_indexes" TO "anon";



ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON SEQUENCES TO "dashboard_user";



ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON FUNCTIONS TO "dashboard_user";



ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON TABLES TO "dashboard_user";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "service_role";



