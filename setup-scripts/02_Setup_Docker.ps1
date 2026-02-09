<#
.SYNOPSIS
    Anna's Booktable  -  Docker Infrastructure Setup
    Creates docker-compose.yml, database schema, seed data, and starts all containers.
#>

param(
    [string]$ProjectRoot = "D:\Dev\AnnaBooktable"
)

$ErrorActionPreference = "Stop"

function Write-Step   { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK     { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip   { param($msg) Write-Host "  [SKIP]  $msg" -ForegroundColor DarkGray }
function Write-Warn   { param($msg) Write-Host "  [WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail   { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }

Set-Location $ProjectRoot

# ============================================================
# Verify Docker is running
# ============================================================
Write-Step "Checking Docker"

try {
    docker info 2>$null | Out-Null
    Write-OK "Docker is running"
} catch {
    Write-Fail "Docker is not running. Please start Docker Desktop and re-run."
    exit 1
}

# ============================================================
# Create docker-compose.yml
# ============================================================
Write-Step "Creating docker-compose.yml"

$composeFile = Join-Path $ProjectRoot "docker-compose.yml"

@'
# Anna's Booktable  -  Local Development Infrastructure
# Usage: docker compose up -d

services:
  # ===== PostgreSQL 16 (Primary Database) =====
  postgres:
    image: postgres:16-alpine
    container_name: booktable-postgres
    environment:
      POSTGRES_DB: booktable
      POSTGRES_USER: booktable_admin
      POSTGRES_PASSWORD: LocalDev123!
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U booktable_admin -d booktable"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  # ===== Redis 7 (Cache + Holds + Idempotency) =====
  redis:
    image: redis:7-alpine
    container_name: booktable-redis
    ports:
      - "6379:6379"
    command: >
      redis-server
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  # ===== Elasticsearch 8 (Search) =====
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: booktable-elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - cluster.name=booktable-search
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 10
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1g

  # ===== RabbitMQ 3 (Message Bus  -  dev substitute for Azure Service Bus) =====
  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: booktable-rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "check_port_connectivity"]
      interval: 10s
      timeout: 10s
      retries: 10
    restart: unless-stopped

  # ===== Seq (Structured Log Viewer  -  dev substitute for Azure Log Analytics) =====
  seq:
    image: datalust/seq:latest
    container_name: booktable-seq
    environment:
      - ACCEPT_EULA=Y
    ports:
      - "5341:5341"
      - "8080:80"
    volumes:
      - seq_data:/data
    restart: unless-stopped

  # ===== Redis Insight (Redis GUI  -  optional) =====
  redis-insight:
    image: redis/redisinsight:latest
    container_name: booktable-redis-insight
    ports:
      - "5540:5540"
    depends_on:
      redis:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  es_data:
  rabbitmq_data:
  seq_data:
'@ | Out-File -FilePath $composeFile -Encoding utf8

Write-OK "docker-compose.yml created"

# ============================================================
# Create Database Schema
# ============================================================
Write-Step "Creating database schema (db/init/01_schema.sql)"

$dbDir = Join-Path $ProjectRoot "db/init"
New-Item -ItemType Directory -Path $dbDir -Force | Out-Null

$schemaFile = Join-Path $dbDir "01_schema.sql"

@'
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
-- Partitioned by date for performance
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

    PRIMARY KEY (slot_id, date)
) PARTITION BY RANGE (date);

-- Create partitions: current month + 6 months forward + 1 month back
DO $$
DECLARE
    start_date DATE := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month');
    end_date DATE;
    partition_name TEXT;
BEGIN
    FOR i IN 0..7 LOOP
        end_date := start_date + INTERVAL '1 month';
        partition_name := 'time_slots_' || TO_CHAR(start_date, 'YYYY_MM');

        IF NOT EXISTS (
            SELECT 1 FROM pg_class WHERE relname = partition_name
        ) THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF time_slots
                 FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_date, end_date
            );
        END IF;

        start_date := end_date;
    END LOOP;
END $$;

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
'@ | Out-File -FilePath $schemaFile -Encoding utf8

Write-OK "Schema created: db/init/01_schema.sql"

# ============================================================
# Create Seed Data
# ============================================================
Write-Step "Creating seed data (db/init/02_seed_data.sql)"

$seedFile = Join-Path $dbDir "02_seed_data.sql"

@'
-- ============================================================
-- Anna's Booktable  -  Seed Data for Development
-- ============================================================

-- ===== USERS (test accounts) =====
INSERT INTO users (user_id, email, password_hash, first_name, last_name, phone, preferences) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'anna@test.com',     '$2a$10$testhashedpassword1', 'Anna',    'Developer', '+1-206-555-0001', '{"cuisine_prefs": ["sushi", "italian"], "price_range": [2,3]}'),
    ('a0000000-0000-0000-0000-000000000002', 'bob@test.com',      '$2a$10$testhashedpassword2', 'Bob',     'Tester',    '+1-206-555-0002', '{"cuisine_prefs": ["mexican", "thai"]}'),
    ('a0000000-0000-0000-0000-000000000003', 'carol@test.com',    '$2a$10$testhashedpassword3', 'Carol',   'Manager',   '+1-206-555-0003', '{"cuisine_prefs": ["french"]}'),
    ('a0000000-0000-0000-0000-000000000004', 'dave@test.com',     '$2a$10$testhashedpassword4', 'Dave',    'Foodie',    '+1-206-555-0004', '{}'),
    ('a0000000-0000-0000-0000-000000000005', 'eve@test.com',      '$2a$10$testhashedpassword5', 'Eve',     'Critic',    '+1-206-555-0005', '{"cuisine_prefs": ["sushi", "french", "italian"]}');

-- ===== RESTAURANTS =====
INSERT INTO restaurants (restaurant_id, name, cuisine, price_level, address, city, state, zip_code, latitude, longitude, avg_rating, description, operating_hours, amenities) VALUES
    ('b0000000-0000-0000-0000-000000000001', 'The Sushi Bar',        'sushi',    3, '123 Pike St',      'Seattle',       'WA', '98101', 47.6097, -122.3331, 4.50, 'Premium omakase and sushi in downtown Seattle.',
     '{"mon":{"open":"11:30","close":"22:00"},"tue":{"open":"11:30","close":"22:00"},"wed":{"open":"11:30","close":"22:00"},"thu":{"open":"11:30","close":"22:00"},"fri":{"open":"11:30","close":"23:00"},"sat":{"open":"12:00","close":"23:00"},"sun":{"open":"12:00","close":"21:00"}}',
     '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

    ('b0000000-0000-0000-0000-000000000002', 'Bella Napoli',         'italian',  2, '456 Broadway Ave',  'Seattle',       'WA', '98102', 47.6135, -122.3210, 4.20, 'Authentic Neapolitan pizza and pasta.',
     '{"mon":{"open":"11:00","close":"22:00"},"tue":{"open":"11:00","close":"22:00"},"wed":{"open":"11:00","close":"22:00"},"thu":{"open":"11:00","close":"22:00"},"fri":{"open":"11:00","close":"23:00"},"sat":{"open":"10:00","close":"23:00"},"sun":{"open":"10:00","close":"21:00"}}',
     '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

    ('b0000000-0000-0000-0000-000000000003', 'Le Petit Bistro',      'french',   4, '789 Madison St',    'Seattle',       'WA', '98104', 47.6080, -122.3250, 4.80, 'Fine French dining with a Pacific Northwest twist.',
     '{"tue":{"open":"17:00","close":"22:00"},"wed":{"open":"17:00","close":"22:00"},"thu":{"open":"17:00","close":"22:00"},"fri":{"open":"17:00","close":"23:00"},"sat":{"open":"17:00","close":"23:00"}}',
     '{"wifi": false, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

    ('b0000000-0000-0000-0000-000000000004', 'Taco Libre',           'mexican',  1, '321 Rainier Ave',   'Seattle',       'WA', '98118', 47.5630, -122.2990, 4.10, 'Street-style tacos and creative Mexican cuisine.',
     '{"mon":{"open":"10:00","close":"22:00"},"tue":{"open":"10:00","close":"22:00"},"wed":{"open":"10:00","close":"22:00"},"thu":{"open":"10:00","close":"22:00"},"fri":{"open":"10:00","close":"23:00"},"sat":{"open":"10:00","close":"23:00"},"sun":{"open":"10:00","close":"21:00"}}',
     '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

    ('b0000000-0000-0000-0000-000000000005', 'Golden Dragon',        'chinese',  2, '888 King St',       'Seattle',       'WA', '98104', 47.5985, -122.3230, 3.90, 'Dim sum and Cantonese classics in the International District.',
     '{"mon":{"open":"10:00","close":"22:00"},"tue":{"open":"10:00","close":"22:00"},"wed":{"open":"10:00","close":"22:00"},"thu":{"open":"10:00","close":"22:00"},"fri":{"open":"10:00","close":"23:00"},"sat":{"open":"09:00","close":"23:00"},"sun":{"open":"09:00","close":"22:00"}}',
     '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

    ('b0000000-0000-0000-0000-000000000006', 'Evergreen Thai',       'thai',     2, '555 University Way', 'Seattle',      'WA', '98105', 47.6615, -122.3128, 4.30, 'Vibrant Thai flavors in the University District.',
     '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"12:00","close":"22:00"},"sun":{"open":"12:00","close":"21:00"}}',
     '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}');

-- ===== TABLE GROUPS =====
INSERT INTO table_groups (table_group_id, restaurant_id, name, attributes, pricing, display_order) VALUES
    -- The Sushi Bar
    ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Sushi Bar',     '{"counter": true}',                           '{"base_multiplier": 1.2}',  1),
    ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'Main Dining',   '{"indoor": true}',                            '{"base_multiplier": 1.0}',  2),
    ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'Private Room',  '{"private": true, "min_spend": 200}',         '{"base_multiplier": 1.5}',  3),
    -- Bella Napoli
    ('c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002', 'Patio',         '{"outdoor": true, "heated": true}',           '{"base_multiplier": 1.1}',  1),
    ('c0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000002', 'Main Dining',   '{"indoor": true}',                            '{"base_multiplier": 1.0}',  2),
    -- Le Petit Bistro
    ('c0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000003', 'Main Dining',   '{"indoor": true, "fireplace": true}',         '{"base_multiplier": 1.0}',  1),
    ('c0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000003', 'Wine Cellar',   '{"private": true, "wine_pairing": true}',     '{"base_multiplier": 2.0}',  2);

-- ===== TABLES =====
INSERT INTO tables (table_id, restaurant_id, table_group_id, table_number, capacity, min_capacity, attributes) VALUES
    -- The Sushi Bar (8 tables)
    ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'B1', 2, 1, '{"bar_seat": true}'),
    ('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'B2', 2, 1, '{"bar_seat": true}'),
    ('d0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'B3', 4, 2, '{"bar_seat": true}'),
    ('d0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'T1', 2, 1, '{}'),
    ('d0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'T2', 4, 2, '{}'),
    ('d0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'T3', 4, 2, '{}'),
    ('d0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'T4', 6, 3, '{}'),
    ('d0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'P1', 10, 6, '{"private": true}'),

    -- Bella Napoli (6 tables)
    ('d0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000004', 'O1', 2, 1, '{"outdoor": true}'),
    ('d0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000004', 'O2', 4, 2, '{"outdoor": true}'),
    ('d0000000-0000-0000-0000-000000000011', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000005', 'M1', 2, 1, '{}'),
    ('d0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000005', 'M2', 4, 2, '{}'),
    ('d0000000-0000-0000-0000-000000000013', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000005', 'M3', 6, 3, '{}'),
    ('d0000000-0000-0000-0000-000000000014', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000005', 'M4', 8, 4, '{}'),

    -- Le Petit Bistro (5 tables)
    ('d0000000-0000-0000-0000-000000000015', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000006', 'A1', 2, 2, '{"window": true}'),
    ('d0000000-0000-0000-0000-000000000016', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000006', 'A2', 2, 2, '{}'),
    ('d0000000-0000-0000-0000-000000000017', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000006', 'A3', 4, 2, '{"fireplace": true}'),
    ('d0000000-0000-0000-0000-000000000018', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000006', 'A4', 4, 2, '{}'),
    ('d0000000-0000-0000-0000-000000000019', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000007', 'W1', 8, 6, '{"wine_cellar": true}');

-- ===== GENERATE TIME SLOTS (next 30 days for all restaurants) =====
DO $$
DECLARE
    r RECORD;
    t RECORD;
    d DATE;
    slot_time TIME;
    slot_start TIMESTAMP;
    slot_end TIMESTAMP;
BEGIN
    FOR r IN SELECT restaurant_id FROM restaurants LOOP
        FOR t IN SELECT table_id, table_group_id, capacity, restaurant_id FROM tables WHERE restaurant_id = r.restaurant_id LOOP
            FOR d IN SELECT generate_series(CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days', '1 day')::date LOOP
                -- Generate slots from 11:00 to 21:00 in 90-minute intervals
                FOR slot_time IN SELECT generate_series('11:00'::time, '21:00'::time, '90 minutes'::interval)::time LOOP
                    slot_start := d + slot_time;
                    slot_end := slot_start + INTERVAL '90 minutes';

                    INSERT INTO time_slots (restaurant_id, table_id, table_group_id, start_time, end_time, status, capacity)
                    VALUES (t.restaurant_id, t.table_id, t.table_group_id, slot_start, slot_end, 'AVAILABLE', t.capacity)
                    ON CONFLICT (restaurant_id, table_id, start_time) DO NOTHING;
                END LOOP;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- ===== DEFAULT POLICIES =====
INSERT INTO restaurant_policies (restaurant_id, policy_type, time_range, rules, priority) VALUES
    -- The Sushi Bar policies
    ('b0000000-0000-0000-0000-000000000001', 'hold_duration',     'default', '{"seconds": 300}',        0),
    ('b0000000-0000-0000-0000-000000000001', 'hold_duration',     'T-24h',   '{"seconds": 120}',        10),
    ('b0000000-0000-0000-0000-000000000001', 'hold_duration',     'T-6h',    '{"seconds": 0}',          20),
    ('b0000000-0000-0000-0000-000000000001', 'cancellation_fee',  'default', '{"percentage": 0}',       0),
    ('b0000000-0000-0000-0000-000000000001', 'cancellation_fee',  'T-48h',   '{"percentage": 50}',      10),
    ('b0000000-0000-0000-0000-000000000001', 'cancellation_fee',  'T-24h',   '{"percentage": 100}',     20),
    -- Le Petit Bistro policies (stricter  -  fine dining)
    ('b0000000-0000-0000-0000-000000000003', 'hold_duration',     'default', '{"seconds": 300}',        0),
    ('b0000000-0000-0000-0000-000000000003', 'hold_duration',     'T-48h',   '{"seconds": 60}',         10),
    ('b0000000-0000-0000-0000-000000000003', 'cancellation_fee',  'default', '{"percentage": 0}',       0),
    ('b0000000-0000-0000-0000-000000000003', 'cancellation_fee',  'T-7d',    '{"percentage": 50}',      10),
    ('b0000000-0000-0000-0000-000000000003', 'cancellation_fee',  'T-48h',   '{"percentage": 100}',     20);

DO $$ BEGIN RAISE NOTICE '[OK] Seed data loaded: 5 users, 6 restaurants, 19 tables, time slots for 30 days'; END $$;
'@ | Out-File -FilePath $seedFile -Encoding utf8

Write-OK "Seed data created: db/init/02_seed_data.sql"

# ============================================================
# Start Docker Containers
# ============================================================
Write-Step "Starting Docker containers"

docker compose up -d 2>&1

# Wait for health checks
Write-Host "    Waiting for services to be healthy..." -ForegroundColor Gray
$maxWait = 60
$waited = 0

while ($waited -lt $maxWait) {
    $pgReady = docker inspect --format='{{.State.Health.Status}}' booktable-postgres 2>$null
    $redisReady = docker inspect --format='{{.State.Health.Status}}' booktable-redis 2>$null

    if ($pgReady -eq "healthy" -and $redisReady -eq "healthy") {
        break
    }

    Start-Sleep -Seconds 3
    $waited += 3
    Write-Host "    ...waiting ($waited/$maxWait sec)" -ForegroundColor Gray
}

# Report status
$containers = @("booktable-postgres", "booktable-redis", "booktable-elasticsearch", "booktable-rabbitmq", "booktable-seq")
foreach ($c in $containers) {
    $status = docker inspect --format='{{.State.Status}}' $c 2>$null
    $health = docker inspect --format='{{.State.Health.Status}}' $c 2>$null
    if ($status -eq "running") {
        Write-OK "$c  -  running $(if ($health) { "($health)" })"
    } else {
        Write-Warn "$c  -  $status"
    }
}

# Quick count of seeded data
Write-Step "Verifying seed data"
$slotCount = docker exec booktable-postgres psql -U booktable_admin -d booktable -t -c "SELECT COUNT(*) FROM time_slots;" 2>$null
$restCount = docker exec booktable-postgres psql -U booktable_admin -d booktable -t -c "SELECT COUNT(*) FROM restaurants;" 2>$null

if ($slotCount) {
    Write-OK "Restaurants: $($restCount.Trim()), Time slots: $($slotCount.Trim())"
} else {
    Write-Warn "Could not verify seed data  -  database may still be initializing"
}

Write-Host ""
Write-OK "Docker infrastructure is ready!"
Write-Host ""
Write-Host "    Service URLs:" -ForegroundColor Gray
Write-Host "    PostgreSQL:  localhost:5432  (booktable_admin / LocalDev123!)" -ForegroundColor Gray
Write-Host "    Redis:       localhost:6379" -ForegroundColor Gray
Write-Host "    Elastic:     http://localhost:9200" -ForegroundColor Gray
Write-Host "    RabbitMQ:    http://localhost:15672 (guest / guest)" -ForegroundColor Gray
Write-Host "    Seq Logs:    http://localhost:8080" -ForegroundColor Gray
Write-Host "    RedisInsight: http://localhost:5540" -ForegroundColor Gray
