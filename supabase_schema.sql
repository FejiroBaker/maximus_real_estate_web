-- ═══════════════════════════════════════════════════════════════════════════
-- MAXIMUS REAL ESTATE — COMPLETE SUPABASE SCHEMA
-- Run this ENTIRE script in: Supabase Dashboard → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- USERS
CREATE TABLE IF NOT EXISTS public.users (
  id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name                    TEXT NOT NULL DEFAULT '',
  email                   TEXT NOT NULL DEFAULT '',
  user_type               TEXT NOT NULL DEFAULT 'buyer'
                            CHECK (user_type IN ('buyer','seller','agent','admin')),
  phone                   TEXT,
  whatsapp_number         TEXT,
  photo_url               TEXT,
  saved_properties        UUID[] DEFAULT '{}',
  bank_account_number     TEXT,
  bank_name               TEXT,
  bank_account_name       TEXT,
  paystack_subaccount_code TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PROPERTIES
CREATE TABLE IF NOT EXISTS public.properties (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL DEFAULT '',
  description     TEXT NOT NULL DEFAULT '',
  price           NUMERIC NOT NULL DEFAULT 0,
  property_type   TEXT NOT NULL DEFAULT 'House',
  type            TEXT NOT NULL DEFAULT 'house',
  listing_type    TEXT NOT NULL DEFAULT 'sale' CHECK (listing_type IN ('sale','rent')),
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','sold','rented')),
  bedrooms        INT NOT NULL DEFAULT 0,
  bathrooms       INT NOT NULL DEFAULT 0,
  area            NUMERIC NOT NULL DEFAULT 0,
  images          TEXT[] DEFAULT '{}',
  videos          TEXT[] DEFAULT '{}',
  address         TEXT DEFAULT '',
  city            TEXT DEFAULT '',
  state           TEXT DEFAULT '',
  country         TEXT DEFAULT 'Nigeria',
  zip_code        TEXT DEFAULT '',
  latitude        NUMERIC DEFAULT 0,
  longitude       NUMERIC DEFAULT 0,
  amenities       TEXT[] DEFAULT '{}',
  owner_id        UUID REFERENCES public.users(id) ON DELETE SET NULL,
  featured        BOOLEAN DEFAULT FALSE,
  is_featured     BOOLEAN DEFAULT FALSE,
  views           INT DEFAULT 0,
  inspection_fee  NUMERIC DEFAULT 0,
  buy_price       NUMERIC DEFAULT 0,
  seller_phone    TEXT DEFAULT '',
  seller_whatsapp TEXT DEFAULT '',
  seller_email    TEXT DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- INSPECTIONS
CREATE TABLE IF NOT EXISTS public.inspections (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id         UUID REFERENCES public.properties(id) ON DELETE CASCADE,
  property_title      TEXT DEFAULT '',
  user_id             UUID REFERENCES public.users(id) ON DELETE CASCADE,
  user_name           TEXT DEFAULT '',
  user_email          TEXT DEFAULT '',
  user_phone          TEXT DEFAULT '',
  inspection_date     TIMESTAMPTZ,
  time_slot           TEXT DEFAULT '',
  inspection_fee      NUMERIC DEFAULT 0,
  payment_status      TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','failed','free')),
  booking_status      TEXT DEFAULT 'pending' CHECK (booking_status IN ('pending','confirmed','cancelled','completed')),
  payment_reference   TEXT DEFAULT '',
  paystack_reference  TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at             TIMESTAMPTZ,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- CONTACT UNLOCKS
CREATE TABLE IF NOT EXISTS public.contact_unlocks (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id         UUID REFERENCES public.properties(id) ON DELETE CASCADE,
  property_title      TEXT DEFAULT '',
  buyer_id            UUID REFERENCES public.users(id) ON DELETE CASCADE,
  buyer_name          TEXT DEFAULT '',
  buyer_email         TEXT DEFAULT '',
  seller_id           UUID,
  unlock_fee          NUMERIC DEFAULT 3000,
  payment_reference   TEXT DEFAULT '',
  paystack_reference  TEXT,
  status              TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','failed')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at             TIMESTAMPTZ
);

-- COMMISSION TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.commission_transactions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type                  TEXT NOT NULL,
  property_id           UUID,
  property_title        TEXT DEFAULT '',
  buyer_id              UUID,
  buyer_name            TEXT DEFAULT '',
  buyer_email           TEXT DEFAULT '',
  seller_id             UUID,
  seller_name           TEXT DEFAULT '',
  amount                NUMERIC DEFAULT 0,
  commission_amount     NUMERIC DEFAULT 0,
  commission_percentage NUMERIC DEFAULT 0,
  seller_payout_amount  NUMERIC DEFAULT 0,
  seller_payout_status  TEXT DEFAULT 'pending_disbursement',
  split_used            BOOLEAN DEFAULT FALSE,
  status                TEXT DEFAULT 'completed',
  payment_reference     TEXT DEFAULT '',
  paystack_reference    TEXT,
  app_owner_email       TEXT DEFAULT '',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at          TIMESTAMPTZ
);

-- SELLER SUBSCRIPTIONS
CREATE TABLE IF NOT EXISTS public.seller_subscriptions (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id           UUID UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  seller_name         TEXT DEFAULT '',
  seller_email        TEXT DEFAULT '',
  plan                TEXT DEFAULT 'basic' CHECK (plan IN ('basic','premium')),
  monthly_fee         NUMERIC DEFAULT 0,
  start_date          TIMESTAMPTZ,
  expiry_date         TIMESTAMPTZ,
  is_active           BOOLEAN DEFAULT FALSE,
  payment_reference   TEXT DEFAULT '',
  paystack_reference  TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_payment_date   TIMESTAMPTZ
);

-- PROPERTY PURCHASES
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
  paystack_reference    TEXT,
  status                TEXT DEFAULT 'pending',
  commission_amount     NUMERIC DEFAULT 0,
  seller_payout_amount  NUMERIC DEFAULT 0,
  split_used            BOOLEAN DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at               TIMESTAMPTZ
);

-- SUBSCRIPTION PAYMENTS
CREATE TABLE IF NOT EXISTS public.subscription_payments (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id           UUID REFERENCES public.users(id),
  seller_name         TEXT DEFAULT '',
  seller_email        TEXT DEFAULT '',
  plan                TEXT DEFAULT 'basic',
  amount              NUMERIC DEFAULT 0,
  payment_reference   TEXT DEFAULT '',
  paystack_reference  TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_properties_status    ON public.properties(status);
CREATE INDEX IF NOT EXISTS idx_properties_type      ON public.properties(type);
CREATE INDEX IF NOT EXISTS idx_properties_owner     ON public.properties(owner_id);
CREATE INDEX IF NOT EXISTS idx_properties_featured  ON public.properties(is_featured, status);
CREATE INDEX IF NOT EXISTS idx_properties_created   ON public.properties(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inspections_user     ON public.inspections(user_id);
CREATE INDEX IF NOT EXISTS idx_inspections_property ON public.inspections(property_id);
CREATE INDEX IF NOT EXISTS idx_inspections_ref      ON public.inspections(payment_reference);
CREATE INDEX IF NOT EXISTS idx_unlocks_buyer        ON public.contact_unlocks(buyer_id, property_id);
CREATE INDEX IF NOT EXISTS idx_unlocks_ref          ON public.contact_unlocks(payment_reference);
CREATE INDEX IF NOT EXISTS idx_subscriptions_seller ON public.seller_subscriptions(seller_id);
CREATE INDEX IF NOT EXISTS idx_purchases_ref        ON public.property_purchases(payment_reference);
CREATE INDEX IF NOT EXISTS idx_transactions_status  ON public.commission_transactions(status);

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC FUNCTION — Atomic view counter increment
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION increment_property_views(pid UUID)
RETURNS void AS $$
  UPDATE public.properties SET views = views + 1 WHERE id = pid;
$$ LANGUAGE sql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────────────────────────────────────

-- Helper function: is current user admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND user_type = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── USERS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_select_own"   ON public.users FOR SELECT  USING (auth.uid() = id OR is_admin());
CREATE POLICY "users_insert_own"   ON public.users FOR INSERT  WITH CHECK (auth.uid() = id);
CREATE POLICY "users_update_own"   ON public.users FOR UPDATE  USING (auth.uid() = id OR is_admin());

-- ── PROPERTIES ─────────────────────────────────────────────────────────────
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
CREATE POLICY "props_select_active"  ON public.properties FOR SELECT  USING (status = 'active' OR auth.uid() = owner_id OR is_admin());
CREATE POLICY "props_insert_owner"   ON public.properties FOR INSERT  WITH CHECK (auth.uid() = owner_id OR is_admin());
CREATE POLICY "props_update_owner"   ON public.properties FOR UPDATE  USING (auth.uid() = owner_id OR is_admin());
CREATE POLICY "props_delete_admin"   ON public.properties FOR DELETE  USING (is_admin());

-- ── INSPECTIONS ────────────────────────────────────────────────────────────
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "insp_select"  ON public.inspections FOR SELECT  USING (auth.uid() = user_id OR is_admin());
CREATE POLICY "insp_insert"  ON public.inspections FOR INSERT  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "insp_update"  ON public.inspections FOR UPDATE  USING (auth.uid() = user_id OR is_admin());

-- ── CONTACT UNLOCKS ────────────────────────────────────────────────────────
ALTER TABLE public.contact_unlocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "unlock_select" ON public.contact_unlocks FOR SELECT USING (auth.uid() = buyer_id OR is_admin());
CREATE POLICY "unlock_insert" ON public.contact_unlocks FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "unlock_update" ON public.contact_unlocks FOR UPDATE USING (auth.uid() = buyer_id OR is_admin());

-- ── COMMISSION TRANSACTIONS ────────────────────────────────────────────────
ALTER TABLE public.commission_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "comm_admin_all" ON public.commission_transactions FOR ALL USING (is_admin());
-- Allow system inserts (from service calls)
CREATE POLICY "comm_system_insert" ON public.commission_transactions FOR INSERT WITH CHECK (TRUE);

-- ── SELLER SUBSCRIPTIONS ───────────────────────────────────────────────────
ALTER TABLE public.seller_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sub_select"  ON public.seller_subscriptions FOR SELECT USING (auth.uid() = seller_id OR is_admin());
CREATE POLICY "sub_upsert"  ON public.seller_subscriptions FOR ALL   USING (auth.uid() = seller_id OR is_admin());

-- ── PROPERTY PURCHASES ─────────────────────────────────────────────────────
ALTER TABLE public.property_purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "purchase_select" ON public.property_purchases FOR SELECT USING (auth.uid() = buyer_id OR is_admin());
CREATE POLICY "purchase_insert" ON public.property_purchases FOR INSERT WITH CHECK (auth.uid() = buyer_id OR is_admin());
CREATE POLICY "purchase_update" ON public.property_purchases FOR UPDATE USING (auth.uid() = buyer_id OR is_admin());

-- ── SUBSCRIPTION PAYMENTS ──────────────────────────────────────────────────
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "subpay_admin"  ON public.subscription_payments FOR SELECT USING (is_admin());
CREATE POLICY "subpay_insert" ON public.subscription_payments FOR INSERT WITH CHECK (auth.uid() = seller_id OR is_admin());

-- ═══════════════════════════════════════════════════════════════════════════
-- STORAGE BUCKETS — Run separately in Supabase Dashboard → Storage
-- ═══════════════════════════════════════════════════════════════════════════
--
-- 1. Create bucket: property-images  (Public ON)
-- 2. Create bucket: property-videos  (Public ON)
--
-- Then in each bucket, add these Storage Policies:
--
-- policy name: "allow_public_read"
-- Allowed operation: SELECT
-- Policy definition: true
--
-- policy name: "allow_auth_upload"
-- Allowed operation: INSERT
-- Policy definition: (auth.role() = 'authenticated')
--
-- policy name: "allow_owner_delete"
-- Allowed operation: DELETE
-- Policy definition: (auth.role() = 'authenticated')
--
-- ═══════════════════════════════════════════════════════════════════════════
