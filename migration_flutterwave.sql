-- ═══════════════════════════════════════════════════════════════════════════
-- MAXIMUS REAL ESTATE — MIGRATION: Paystack → Flutterwave  (SAFE VERSION)
-- Run this in: Supabase Dashboard → SQL Editor → Run
--
-- FIX: Uses DO $$ blocks with IF EXISTS checks so the script never fails
-- if a column was already renamed or never existed.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. USERS TABLE ──────────────────────────────────────────────────────────
-- Rename paystack_subaccount_code → flutterwave_subaccount_id (if old column exists)
-- OR add flutterwave_subaccount_id fresh (if table was already migrated).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'users'
      AND column_name  = 'paystack_subaccount_code'
  ) THEN
    ALTER TABLE public.users
      RENAME COLUMN paystack_subaccount_code TO flutterwave_subaccount_id;
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'users'
      AND column_name  = 'flutterwave_subaccount_id'
  ) THEN
    ALTER TABLE public.users
      ADD COLUMN flutterwave_subaccount_id TEXT;
  END IF;
END $$;

-- ── 2. INSPECTIONS TABLE ────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'inspections'
      AND column_name  = 'paystack_reference'
  ) THEN
    ALTER TABLE public.inspections
      RENAME COLUMN paystack_reference TO flutterwave_reference;
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'inspections'
      AND column_name  = 'flutterwave_reference'
  ) THEN
    ALTER TABLE public.inspections
      ADD COLUMN flutterwave_reference TEXT;
  END IF;
END $$;

-- Also ensure updated_at column exists (needed by admin screen update)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'inspections'
      AND column_name  = 'updated_at'
  ) THEN
    ALTER TABLE public.inspections
      ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
  END IF;
END $$;

-- ── 3. CONTACT_UNLOCKS TABLE ────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'contact_unlocks'
      AND column_name  = 'paystack_reference'
  ) THEN
    ALTER TABLE public.contact_unlocks
      RENAME COLUMN paystack_reference TO flutterwave_reference;
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'contact_unlocks'
      AND column_name  = 'flutterwave_reference'
  ) THEN
    ALTER TABLE public.contact_unlocks
      ADD COLUMN flutterwave_reference TEXT;
  END IF;
END $$;

-- ── 4. COMMISSION_TRANSACTIONS TABLE ────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'commission_transactions'
      AND column_name  = 'paystack_reference'
  ) THEN
    ALTER TABLE public.commission_transactions
      RENAME COLUMN paystack_reference TO flutterwave_reference;
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'commission_transactions'
      AND column_name  = 'flutterwave_reference'
  ) THEN
    ALTER TABLE public.commission_transactions
      ADD COLUMN flutterwave_reference TEXT;
  END IF;
END $$;

-- Also add seller_payout_amount and split_used if missing (used by FlutterwaveService)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'commission_transactions'
      AND column_name  = 'seller_payout_amount'
  ) THEN
    ALTER TABLE public.commission_transactions
      ADD COLUMN seller_payout_amount NUMERIC DEFAULT 0;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'commission_transactions'
      AND column_name  = 'seller_payout_status'
  ) THEN
    ALTER TABLE public.commission_transactions
      ADD COLUMN seller_payout_status TEXT DEFAULT 'pending_disbursement';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'commission_transactions'
      AND column_name  = 'split_used'
  ) THEN
    ALTER TABLE public.commission_transactions
      ADD COLUMN split_used BOOLEAN DEFAULT FALSE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'commission_transactions'
      AND column_name  = 'app_owner_email'
  ) THEN
    ALTER TABLE public.commission_transactions
      ADD COLUMN app_owner_email TEXT DEFAULT '';
  END IF;
END $$;

-- ── 5. SELLER_SUBSCRIPTIONS TABLE ───────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'seller_subscriptions'
      AND column_name  = 'paystack_reference'
  ) THEN
    ALTER TABLE public.seller_subscriptions
      RENAME COLUMN paystack_reference TO flutterwave_reference;
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'seller_subscriptions'
      AND column_name  = 'flutterwave_reference'
  ) THEN
    ALTER TABLE public.seller_subscriptions
      ADD COLUMN flutterwave_reference TEXT;
  END IF;
END $$;

-- ── 6. PROPERTY_PURCHASES TABLE ─────────────────────────────────────────────
-- Create if it doesn't exist yet
CREATE TABLE IF NOT EXISTS public.property_purchases (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id           UUID REFERENCES public.properties(id),
  property_title        TEXT DEFAULT '',
  buyer_id              UUID REFERENCES public.users(id),
  buyer_name            TEXT DEFAULT '',
  buyer_email           TEXT DEFAULT '',
  seller_id             UUID,
  amount                NUMERIC DEFAULT 0,
  payment_reference     TEXT DEFAULT '',
  flutterwave_reference TEXT,
  status                TEXT DEFAULT 'pending',
  commission_amount     NUMERIC DEFAULT 0,
  seller_payout_amount  NUMERIC DEFAULT 0,
  split_used            BOOLEAN DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at               TIMESTAMPTZ
);

-- If it already existed with paystack_reference, rename safely
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'property_purchases'
      AND column_name  = 'paystack_reference'
  ) THEN
    ALTER TABLE public.property_purchases
      RENAME COLUMN paystack_reference TO flutterwave_reference;
  END IF;
END $$;

-- ── 7. SUBSCRIPTION_PAYMENTS TABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.subscription_payments (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id             UUID REFERENCES public.users(id),
  seller_name           TEXT DEFAULT '',
  seller_email          TEXT DEFAULT '',
  plan                  TEXT DEFAULT 'basic',
  amount                NUMERIC DEFAULT 0,
  payment_reference     TEXT DEFAULT '',
  flutterwave_reference TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'subscription_payments'
      AND column_name  = 'paystack_reference'
  ) THEN
    ALTER TABLE public.subscription_payments
      RENAME COLUMN paystack_reference TO flutterwave_reference;
  END IF;
END $$;

-- ── 8. set_user_type RPC (required by AdminUsersScreen) ─────────────────────
CREATE OR REPLACE FUNCTION set_user_type(
  target_user_id UUID,
  new_type        TEXT
)
RETURNS void AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND user_type = 'admin'
  ) THEN
    RAISE EXCEPTION 'Permission denied: caller is not an admin';
  END IF;

  IF new_type NOT IN ('buyer', 'seller', 'agent', 'admin') THEN
    RAISE EXCEPTION 'Invalid user_type: %', new_type;
  END IF;

  UPDATE public.users
    SET user_type  = new_type,
        updated_at = NOW()
  WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION set_user_type(UUID, TEXT) TO authenticated;

-- ── 9. RLS for new tables ───────────────────────────────────────────────────
ALTER TABLE public.property_purchases   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;

-- Drop policies first (safe if they don't exist — Postgres 9.6+ ignores missing DROP)
DROP POLICY IF EXISTS "purchase_select" ON public.property_purchases;
DROP POLICY IF EXISTS "purchase_insert" ON public.property_purchases;
DROP POLICY IF EXISTS "purchase_update" ON public.property_purchases;
DROP POLICY IF EXISTS "subpay_admin"    ON public.subscription_payments;
DROP POLICY IF EXISTS "subpay_insert"   ON public.subscription_payments;

CREATE POLICY "purchase_select" ON public.property_purchases
  FOR SELECT USING (auth.uid() = buyer_id OR is_admin());
CREATE POLICY "purchase_insert" ON public.property_purchases
  FOR INSERT WITH CHECK (auth.uid() = buyer_id OR is_admin());
CREATE POLICY "purchase_update" ON public.property_purchases
  FOR UPDATE USING (auth.uid() = buyer_id OR is_admin());

CREATE POLICY "subpay_admin"  ON public.subscription_payments
  FOR SELECT USING (is_admin());
CREATE POLICY "subpay_insert" ON public.subscription_payments
  FOR INSERT WITH CHECK (auth.uid() = seller_id OR is_admin());

-- ── 10. Index on new flutterwave_reference columns ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_purchases_ref
  ON public.property_purchases(payment_reference);
CREATE INDEX IF NOT EXISTS idx_comm_ref
  ON public.commission_transactions(payment_reference);

-- ═══════════════════════════════════════════════════════════════════════════
-- DONE. All Paystack columns renamed to Flutterwave safely.
-- ═══════════════════════════════════════════════════════════════════════════