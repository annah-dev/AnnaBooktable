-- ============================================================
-- Anna's Booktable  -  Database Schema
-- Based on OpenTable System Design (Approach #2)
-- Auto-runs on first PostgreSQL container startup
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "cube";
CREATE EXTENSION IF NOT EXISTS "earthdistance";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- trigram fuzzy search

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
    user_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    phone           VARCHAR(20),
    preferences     JSONB DEFAULT '{}',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);

-- ============================================================
-- RESTAURANTS
-- ============================================================
CREATE TABLE restaurants (
    restaurant_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(255) NOT NULL,
    cuisine         VARCHAR(50),
    price_level     INT CHECK (price_level BETWEEN 1 AND 4),
    address         TEXT,
    city            VARCHAR(100),
    state           VARCHAR(50),
    zip_code        VARCHAR(20),
    latitude        DECIMAL(10, 8),
    longitude       DECIMAL(11, 8),
    avg_rating      DECIMAL(3, 2) DEFAULT 0.00,
    total_reviews   INT DEFAULT 0,
    operating_hours JSONB DEFAULT '{}',
    amenities       JSONB DEFAULT '{}',
    phone           VARCHAR(20),
    website         VARCHAR(255),
    description     TEXT,
    cover_image_url VARCHAR(500),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_restaurants_cuisine ON restaurants(cuisine);
CREATE INDEX idx_restaurants_city ON restaurants(city);
CREATE INDEX idx_restaurants_active ON restaurants(is_active) WHERE is_active = true;
CREATE INDEX idx_restaurants_location ON restaurants
    USING gist(ll_to_earth(latitude, longitude));
CREATE INDEX idx_restaurants_name_trgm ON restaurants
    USING gin(name gin_trgm_ops);

-- ============================================================
-- TABLE GROUPS (Bonus #2)
-- ============================================================
CREATE TABLE table_groups (
    table_group_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id   UUID NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    name            VARCHAR(50) NOT NULL,
    description     TEXT,
    attributes      JSONB DEFAULT '{}',
    pricing         JSONB DEFAULT '{"base_multiplier": 1.0}',
    display_order   INT DEFAULT 0,
    UNIQUE (restaurant_id, name)
);

CREATE INDEX idx_table_groups_restaurant ON table_groups(restaurant_id);

-- ============================================================
-- TABLES
-- ============================================================
CREATE TABLE tables (
    table_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id   UUID NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    table_group_id  UUID REFERENCES table_groups(table_group_id) ON DELETE SET NULL,
    table_number    VARCHAR(10) NOT NULL,
    capacity        INT NOT NULL CHECK (capacity > 0),
    min_capacity    INT DEFAULT 1 CHECK (min_capacity > 0),
    attributes      JSONB DEFAULT '{}',
    status          VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE')),
    UNIQUE (restaurant_id, table_number)
);

CREATE INDEX idx_tables_restaurant ON tables(restaurant_id);
CREATE INDEX idx_tables_restaurant_group ON tables(restaurant_id, table_group_id);

-- ============================================================
-- TIME SLOTS  -  THE HOT TABLE
-- Note: PostgreSQL cannot partition by generated columns,
-- so we use a regular table with a generated date column.
-- ============================================================
CREATE TABLE time_slots (
    slot_id         UUID NOT NULL DEFAULT uuid_generate_v4(),
    restaurant_id   UUID NOT NULL,
    table_id        UUID NOT NULL,
    table_group_id  UUID,
    start_time      TIMESTAMP NOT NULL,
    end_time        TIMESTAMP NOT NULL,
    date            DATE GENERATED ALWAYS AS (start_time::date) STORED,
    status          VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'
                    CHECK (status IN ('AVAILABLE', 'HELD', 'BOOKED', 'BLOCKED')),
    capacity        INT NOT NULL,
    held_by         UUID,
    held_until      TIMESTAMP,

    -- [S] THE CRITICAL SAFETY NET  -  prevents double-booking at DB level
    UNIQUE (restaurant_id, table_id, start_time),

    PRIMARY KEY (slot_id)
);

-- Critical indexes
CREATE INDEX idx_slots_restaurant_date ON time_slots(restaurant_id, date);
CREATE INDEX idx_slots_available ON time_slots(restaurant_id, date, start_time, capacity)
    WHERE status = 'AVAILABLE';
CREATE INDEX idx_slots_search ON time_slots(restaurant_id, date, start_time, status, capacity);
CREATE INDEX idx_slots_group ON time_slots(table_group_id, date, start_time)
    WHERE table_group_id IS NOT NULL;

-- ============================================================
-- RESERVATIONS
-- ============================================================
CREATE TABLE reservations (
    reservation_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           UUID NOT NULL REFERENCES users(user_id),
    restaurant_id     UUID NOT NULL REFERENCES restaurants(restaurant_id),
    slot_id           UUID NOT NULL,
    confirmation_code VARCHAR(10) NOT NULL UNIQUE,
    party_size        INT NOT NULL CHECK (party_size > 0),
    special_requests  TEXT,
    status            VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED'
                      CHECK (status IN ('CONFIRMED', 'CANCELLED', 'NO_SHOW', 'COMPLETED', 'PENDING')),
    deposit_amount    DECIMAL(10, 2) DEFAULT 0.00,
    payment_status    VARCHAR(20) DEFAULT 'NONE'
                      CHECK (payment_status IN ('NONE', 'PENDING', 'CAPTURED', 'REFUNDED', 'FAILED')),
    payment_intent_id VARCHAR(100),
    idempotency_key   VARCHAR(100),
    booked_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP NOT NULL DEFAULT NOW(),

    -- One reservation per time slot
    UNIQUE (slot_id)
);

CREATE INDEX idx_reservations_user ON reservations(user_id, created_at DESC);
CREATE INDEX idx_reservations_restaurant ON reservations(restaurant_id, booked_at DESC);
CREATE INDEX idx_reservations_confirmation ON reservations(confirmation_code);
CREATE INDEX idx_reservations_status ON reservations(status) WHERE status = 'CONFIRMED';
CREATE INDEX idx_reservations_idempotency ON reservations(idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- ============================================================
-- REVIEWS
-- ============================================================
CREATE TABLE reviews (
    review_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(user_id),
    restaurant_id   UUID NOT NULL REFERENCES restaurants(restaurant_id),
    reservation_id  UUID NOT NULL REFERENCES reservations(reservation_id),
    rating          INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment         TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, reservation_id)
);

CREATE INDEX idx_reviews_restaurant ON reviews(restaurant_id, created_at DESC);

-- Trigger: update avg_rating on restaurant after review insert/update
CREATE OR REPLACE FUNCTION update_restaurant_avg_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE restaurants
    SET avg_rating = (
            SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0)
            FROM reviews WHERE restaurant_id = NEW.restaurant_id
        ),
        total_reviews = (
            SELECT COUNT(*) FROM reviews WHERE restaurant_id = NEW.restaurant_id
        ),
        updated_at = NOW()
    WHERE restaurant_id = NEW.restaurant_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_avg_rating
    AFTER INSERT OR UPDATE OR DELETE ON reviews
    FOR EACH ROW EXECUTE FUNCTION update_restaurant_avg_rating();

-- ============================================================
-- RESTAURANT POLICIES (Bonus #3  -  Dynamic Inventory)
-- ============================================================
CREATE TABLE restaurant_policies (
    policy_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id   UUID NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    policy_type     VARCHAR(50) NOT NULL
                    CHECK (policy_type IN ('hold_duration', 'cancellation_fee', 'overbooking_factor')),
    time_range      VARCHAR(20) NOT NULL DEFAULT 'default',
    rules           JSONB NOT NULL DEFAULT '{}',
    priority        INT NOT NULL DEFAULT 0,
    enabled         BOOLEAN DEFAULT true,
    UNIQUE (restaurant_id, policy_type, time_range)
);

CREATE INDEX idx_policies_restaurant ON restaurant_policies(restaurant_id, policy_type);

-- ============================================================
-- HELPER: Generate confirmation code
-- ============================================================
CREATE OR REPLACE FUNCTION generate_confirmation_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no I,O,0,1
    result TEXT := '';
    i INT;
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- HELPER: Auto-update updated_at timestamp
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated      BEFORE UPDATE ON users       FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_restaurants_updated BEFORE UPDATE ON restaurants FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_reservations_updated BEFORE UPDATE ON reservations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Done!
DO $$ BEGIN RAISE NOTICE '[OK] Anna''s Booktable schema created successfully!'; END $$;
