-- Add more tables to all restaurants and generate their time slots
-- This doubles each restaurant's table count approximately

DO $$
DECLARE
    g RECORD;
    new_tables INT;
    tbl_num INT;
    max_num INT;
    cap INT;
    min_cap INT;
    tbl_prefix TEXT;
    new_table_id UUID;
BEGIN
    FOR g IN
        SELECT tg.table_group_id, tg.restaurant_id, tg.name,
               COUNT(t.table_id) AS existing_count
        FROM table_groups tg
        JOIN tables t ON t.table_group_id = tg.table_group_id
        GROUP BY tg.table_group_id, tg.restaurant_id, tg.name
    LOOP
        -- Add tables based on group type
        new_tables := CASE
            WHEN g.name = 'Main Dining' THEN 6     -- add 6 more (was 4)
            WHEN g.name = 'Patio' THEN 3            -- add 3 more (was 2)
            WHEN g.name = 'Private Room' THEN 1     -- add 1 more (was 1)
            WHEN g.name = 'BBQ Grill Seating' THEN 3 -- add 3 more (was 3)
            WHEN g.name = 'Bar' THEN 4              -- add 4 more (was 4)
            ELSE 2
        END;

        tbl_prefix := CASE
            WHEN g.name = 'Main Dining' THEN 'M'
            WHEN g.name = 'Patio' THEN 'P'
            WHEN g.name = 'Private Room' THEN 'R'
            WHEN g.name = 'BBQ Grill Seating' THEN 'G'
            WHEN g.name = 'Bar' THEN 'B'
            ELSE 'T'
        END;

        -- Find the current max table_number for this restaurant
        SELECT COALESCE(MAX(CAST(regexp_replace(table_number, '[^0-9]', '', 'g') AS INT)), 0)
        INTO max_num
        FROM tables WHERE restaurant_id = g.restaurant_id;

        FOR i IN 1..new_tables LOOP
            max_num := max_num + 1;

            -- Varied capacities for realistic mix
            cap := CASE
                WHEN g.name = 'Private Room' THEN 12
                WHEN g.name = 'Bar' AND (i % 3) != 0 THEN 2
                WHEN g.name = 'Bar' THEN 4
                WHEN (i % 5) = 1 THEN 2   -- small deuce
                WHEN (i % 5) = 2 THEN 4   -- four-top
                WHEN (i % 5) = 3 THEN 4   -- four-top
                WHEN (i % 5) = 4 THEN 6   -- six-top
                WHEN (i % 5) = 0 THEN 8   -- eight-top
                ELSE 4
            END;

            min_cap := CASE
                WHEN cap <= 2 THEN 1
                WHEN cap <= 4 THEN 2
                WHEN cap <= 6 THEN 3
                ELSE 4
            END;

            new_table_id := uuid_generate_v4();

            INSERT INTO tables (table_id, restaurant_id, table_group_id, table_number, capacity, min_capacity, attributes)
            VALUES (new_table_id, g.restaurant_id, g.table_group_id, tbl_prefix || max_num, cap, min_cap, '{}');

            -- Generate time slots for this new table (next 30 days, same pattern as seed)
            INSERT INTO time_slots (restaurant_id, table_id, table_group_id, start_time, end_time, status, capacity)
            SELECT
                g.restaurant_id,
                new_table_id,
                g.table_group_id,
                d.day + s.slot_time AS start_time,
                d.day + s.slot_time + INTERVAL '90 minutes' AS end_time,
                'AVAILABLE',
                cap
            FROM
                generate_series(CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days', INTERVAL '1 day') AS d(day)
            CROSS JOIN (
                SELECT (INTERVAL '1 hour' * h) AS slot_time
                FROM generate_series(11, 20) AS h
            ) AS s;
        END LOOP;
    END LOOP;
END $$;

-- Report results
DO $$
DECLARE
    tbl_count INT;
    slot_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO tbl_count FROM tables;
    SELECT COUNT(*) INTO slot_count FROM time_slots WHERE date >= CURRENT_DATE;
    RAISE NOTICE '[OK] Now have % tables and % future time slots', tbl_count, slot_count;
END $$;
