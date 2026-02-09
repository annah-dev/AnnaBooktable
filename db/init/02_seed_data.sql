-- ============================================================
-- Anna's Booktable  -  Seed Data for Development
-- ============================================================

-- ===== USERS (test accounts) =====
INSERT INTO users (user_id, email, password_hash, first_name, last_name, phone, preferences) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'anna@test.com',     '$2a$10$testhashedpassword1', 'Anna',    'Developer', '+1-206-555-0001', '{"cuisine_prefs": ["sushi", "italian"], "price_range": [2,3]}'),
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
