-- ============================================================
-- Anna's Booktable  -  Seed Data: Bellevue / Redmond Restaurants
-- ============================================================

-- ===== USERS (test accounts) =====
INSERT INTO users (user_id, email, password_hash, first_name, last_name, phone, preferences) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'anna@test.com',     '$2a$10$testhashedpassword1', 'Anna',    'Developer', '+1-425-555-0001', '{"cuisine_prefs": ["Japanese", "Italian"], "price_range": [2,3]}'),
    ('a0000000-0000-0000-0000-000000000002', 'bob@test.com',      '$2a$10$testhashedpassword2', 'Bob',     'Tester',    '+1-425-555-0002', '{"cuisine_prefs": ["Mexican", "Thai"]}'),
    ('a0000000-0000-0000-0000-000000000003', 'carol@test.com',    '$2a$10$testhashedpassword3', 'Carol',   'Manager',   '+1-425-555-0003', '{"cuisine_prefs": ["French"]}'),
    ('a0000000-0000-0000-0000-000000000004', 'dave@test.com',     '$2a$10$testhashedpassword4', 'Dave',    'Foodie',    '+1-425-555-0004', '{}'),
    ('a0000000-0000-0000-0000-000000000005', 'eve@test.com',      '$2a$10$testhashedpassword5', 'Eve',     'Critic',    '+1-425-555-0005', '{"cuisine_prefs": ["Japanese", "French", "Italian"]}');

-- ===== RESTAURANTS (~60 real Bellevue / Redmond area restaurants) =====
INSERT INTO restaurants (restaurant_id, name, cuisine, price_level, address, city, state, zip_code, latitude, longitude, avg_rating, description, operating_hours, amenities) VALUES

-- === JAPANESE (7) ===
('b0000000-0000-0000-0000-000000000001', 'Flo Japanese Restaurant', 'Japanese', 3, '1150 106th Ave NE', 'Bellevue', 'WA', '98004', 47.6168, -122.1960, 4.60, 'Upscale Japanese restaurant known for fresh sushi and omakase experiences in downtown Bellevue.',
 '{"mon":{"open":"11:30","close":"21:30"},"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"12:00","close":"22:00"},"sun":{"open":"12:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000002', 'Sushi Maru', 'Japanese', 2, '15015 Main St #113', 'Bellevue', 'WA', '98007', 47.6211, -122.1533, 4.30, 'Popular neighborhood sushi spot with generous portions and friendly service.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:30","close":"22:00"},"sun":{"open":"11:30","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000003', 'Japonessa Sushi Cocina', 'Japanese', 4, '10455 NE 5th Pl', 'Bellevue', 'WA', '98004', 47.6148, -122.1930, 4.50, 'Trendy sushi lounge blending Japanese flavors with Latin influences. Known for creative rolls and vibrant atmosphere.',
 '{"tue":{"open":"16:00","close":"22:00"},"wed":{"open":"16:00","close":"22:00"},"thu":{"open":"16:00","close":"22:00"},"fri":{"open":"16:00","close":"23:00"},"sat":{"open":"12:00","close":"23:00"},"sun":{"open":"12:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000004', 'Izakaya Mita', 'Japanese', 2, '710 NW Juniper St #100', 'Redmond', 'WA', '98052', 47.6740, -122.1260, 4.20, 'Cozy izakaya serving authentic Japanese small plates, ramen, and sake in Redmond.',
 '{"mon":{"open":"11:30","close":"21:00"},"tue":{"open":"11:30","close":"21:00"},"wed":{"open":"11:30","close":"21:00"},"thu":{"open":"11:30","close":"21:00"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"12:00","close":"22:00"},"sun":{"open":"12:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000005', 'Zen Ramen & Sushi', 'Japanese', 2, '15230 NE 24th St', 'Redmond', 'WA', '98052', 47.6310, -122.1430, 4.10, 'Casual ramen and sushi restaurant with rich broths and creative rolls.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:30","close":"21:30"},"sun":{"open":"11:30","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000006', 'Sushi Hana', 'Japanese', 2, '2601 76th Ave SE', 'Mercer Island', 'WA', '98040', 47.5728, -122.2256, 4.40, 'Long-standing sushi favorite on Mercer Island with top-quality fish and a loyal following.',
 '{"tue":{"open":"11:30","close":"21:00"},"wed":{"open":"11:30","close":"21:00"},"thu":{"open":"11:30","close":"21:00"},"fri":{"open":"11:30","close":"21:30"},"sat":{"open":"12:00","close":"21:30"},"sun":{"open":"12:00","close":"20:30"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000007', 'Oto Sushi', 'Japanese', 3, '10245 Main St', 'Bellevue', 'WA', '98004', 47.6130, -122.1992, 4.30, 'Intimate omakase-focused restaurant with daily fish flown in from Tsukiji Market.',
 '{"wed":{"open":"17:00","close":"22:00"},"thu":{"open":"17:00","close":"22:00"},"fri":{"open":"17:00","close":"22:30"},"sat":{"open":"17:00","close":"22:30"},"sun":{"open":"17:00","close":"21:00"}}',
 '{"wifi": false, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

-- === ITALIAN (5) ===
('b0000000-0000-0000-0000-000000000008', 'Bis on Main', 'Italian', 3, '10213 Main St', 'Bellevue', 'WA', '98004', 47.6133, -122.1996, 4.50, 'Upscale Italian bistro in Old Bellevue known for handmade pasta and an award-winning wine list.',
 '{"mon":{"open":"11:30","close":"21:30"},"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000009', 'Calcutta Grill & Tavern', 'Italian', 3, '15500 SE 30th Pl', 'Bellevue', 'WA', '98007', 47.5980, -122.1500, 4.30, 'Warm neighborhood Italian restaurant with wood-fired specialties and seasonal ingredients.',
 '{"tue":{"open":"17:00","close":"21:30"},"wed":{"open":"17:00","close":"21:30"},"thu":{"open":"17:00","close":"21:30"},"fri":{"open":"17:00","close":"22:00"},"sat":{"open":"17:00","close":"22:00"},"sun":{"open":"16:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000010', 'Romio''s Pizza & Pasta', 'Italian', 1, '11523 NE 164th St', 'Redmond', 'WA', '98052', 47.6840, -122.1230, 3.80, 'Family-friendly Italian restaurant serving hearty pizza and pasta dishes.',
 '{"mon":{"open":"11:00","close":"22:00"},"tue":{"open":"11:00","close":"22:00"},"wed":{"open":"11:00","close":"22:00"},"thu":{"open":"11:00","close":"22:00"},"fri":{"open":"11:00","close":"23:00"},"sat":{"open":"11:00","close":"23:00"},"sun":{"open":"11:00","close":"22:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000011', 'Tavola Italian Kitchen', 'Italian', 2, '16564 Cleveland St', 'Redmond', 'WA', '98052', 47.6730, -122.1250, 4.20, 'Rustic Italian kitchen with handmade pastas, artisan pizzas, and a well-curated wine selection.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000012', 'Porcella Urban Market', 'Italian', 2, '1208 156th Ave NE', 'Bellevue', 'WA', '98007', 47.6208, -122.1350, 4.00, 'Italian market-meets-restaurant with fresh deli, wood-fired pizzas, and imported Italian goods.',
 '{"mon":{"open":"10:00","close":"21:00"},"tue":{"open":"10:00","close":"21:00"},"wed":{"open":"10:00","close":"21:00"},"thu":{"open":"10:00","close":"21:00"},"fri":{"open":"10:00","close":"22:00"},"sat":{"open":"10:00","close":"22:00"},"sun":{"open":"10:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

-- === AMERICAN (6) ===
('b0000000-0000-0000-0000-000000000013', 'John Howie Steak', 'Steakhouse', 4, '11111 NE 8th St', 'Bellevue', 'WA', '98004', 47.6155, -122.1875, 4.70, 'Premier steakhouse featuring dry-aged USDA Prime beef, an extensive wine list, and impeccable service.',
 '{"mon":{"open":"16:00","close":"22:00"},"tue":{"open":"16:00","close":"22:00"},"wed":{"open":"16:00","close":"22:00"},"thu":{"open":"16:00","close":"22:00"},"fri":{"open":"16:00","close":"23:00"},"sat":{"open":"16:00","close":"23:00"},"sun":{"open":"16:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000014', 'The Lakehouse', 'American', 3, '10245 NE 12th St', 'Bellevue', 'WA', '98004', 47.6175, -122.1990, 4.40, 'Pacific Northwest-inspired cuisine with seasonal menus and waterfront views.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"10:00","close":"22:00"},"sun":{"open":"10:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000015', 'Ascend Prime Steak & Sushi', 'Steakhouse', 4, '10400 NE 4th St, 31st Floor', 'Bellevue', 'WA', '98004', 47.6142, -122.1940, 4.60, 'Rooftop fine dining with panoramic views, premium steaks, and a raw bar. Stunning 31st-floor setting.',
 '{"tue":{"open":"16:30","close":"22:00"},"wed":{"open":"16:30","close":"22:00"},"thu":{"open":"16:30","close":"22:00"},"fri":{"open":"16:30","close":"23:00"},"sat":{"open":"16:30","close":"23:00"},"sun":{"open":"16:30","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000016', 'Woodblock', 'American', 3, '10635 NE 8th St', 'Bellevue', 'WA', '98004', 47.6155, -122.1900, 4.20, 'Farm-to-table American restaurant focusing on seasonal ingredients and craft cocktails.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"10:00","close":"22:00"},"sun":{"open":"10:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000017', 'The Stone House Café', 'American', 2, '16244 Cleveland St', 'Redmond', 'WA', '98052', 47.6735, -122.1255, 4.10, 'Charming café in a historic stone building, serving American comfort food and weekend brunch.',
 '{"mon":{"open":"08:00","close":"21:00"},"tue":{"open":"08:00","close":"21:00"},"wed":{"open":"08:00","close":"21:00"},"thu":{"open":"08:00","close":"21:00"},"fri":{"open":"08:00","close":"22:00"},"sat":{"open":"08:00","close":"22:00"},"sun":{"open":"08:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000018', 'Matador Bellevue', 'American', 2, '480 106th Ave NE', 'Bellevue', 'WA', '98004', 47.6152, -122.1960, 4.00, 'Lively gastropub with craft cocktails, shareable plates, and a fun social atmosphere.',
 '{"mon":{"open":"11:00","close":"00:00"},"tue":{"open":"11:00","close":"00:00"},"wed":{"open":"11:00","close":"00:00"},"thu":{"open":"11:00","close":"00:00"},"fri":{"open":"11:00","close":"01:00"},"sat":{"open":"10:00","close":"01:00"},"sun":{"open":"10:00","close":"00:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

-- === KOREAN (5) ===
('b0000000-0000-0000-0000-000000000019', 'Palate Korean BBQ', 'Korean', 3, '14603 NE 20th St', 'Bellevue', 'WA', '98007', 47.6300, -122.1410, 4.30, 'Modern Korean BBQ with premium meats, banchan spread, and a stylish dining room.',
 '{"mon":{"open":"11:00","close":"22:00"},"tue":{"open":"11:00","close":"22:00"},"wed":{"open":"11:00","close":"22:00"},"thu":{"open":"11:00","close":"22:00"},"fri":{"open":"11:00","close":"23:00"},"sat":{"open":"11:00","close":"23:00"},"sun":{"open":"11:00","close":"22:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000020', 'Kanak Korean BBQ', 'Korean', 2, '14200 NE 20th St', 'Bellevue', 'WA', '98007', 47.6298, -122.1450, 4.10, 'All-you-can-eat Korean BBQ with a wide selection of meats and sides.',
 '{"mon":{"open":"11:00","close":"22:00"},"tue":{"open":"11:00","close":"22:00"},"wed":{"open":"11:00","close":"22:00"},"thu":{"open":"11:00","close":"22:00"},"fri":{"open":"11:00","close":"23:00"},"sat":{"open":"11:00","close":"23:00"},"sun":{"open":"11:00","close":"22:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000021', 'OKT Kitchen', 'Korean', 2, '8105 161st Ave NE', 'Redmond', 'WA', '98052', 47.6520, -122.1280, 4.20, 'Contemporary Korean fusion restaurant with inventive dishes and craft soju cocktails.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000022', 'Bonchon Bellevue', 'Korean', 2, '550 106th Ave NE #120', 'Bellevue', 'WA', '98004', 47.6158, -122.1960, 4.00, 'Famous Korean fried chicken chain with crispy double-fried wings and Korean classics.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000023', 'Hosoonyi Korean', 'Korean', 2, '7830 Leary Way NE', 'Redmond', 'WA', '98052', 47.6690, -122.1340, 4.30, 'Homestyle Korean cooking with generous portions and a welcoming atmosphere.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

-- === CHINESE (5) ===
('b0000000-0000-0000-0000-000000000024', 'Din Tai Fung Bellevue', 'Chinese', 2, '700 Bellevue Way NE', 'Bellevue', 'WA', '98004', 47.6165, -122.2010, 4.60, 'World-famous Taiwanese chain serving exquisite xiaolongbao and dim sum in Lincoln Square.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"10:00","close":"22:00"},"sun":{"open":"10:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000025', 'Bamboo Garden', 'Chinese', 2, '15446 Bel-Red Rd', 'Bellevue', 'WA', '98007', 47.6220, -122.1440, 4.10, 'Vegetarian Chinese restaurant with creative plant-based dishes that satisfy even meat lovers.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000026', 'Facing East', 'Taiwanese', 3, '1075 Bellevue Way NE', 'Bellevue', 'WA', '98004', 47.6185, -122.2005, 4.40, 'Acclaimed Taiwanese restaurant with authentic street food and signature three-cup chicken.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000027', 'Sichuan Cuisine', 'Chinese', 2, '15005 NE 24th St #G', 'Redmond', 'WA', '98052', 47.6310, -122.1440, 4.20, 'Authentic Sichuan restaurant with fiery mapo tofu, dan dan noodles, and numbing hotpot.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:30"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000028', 'Seven Stars Pepper', 'Chinese', 2, '1207 S Jackson St #108', 'Bellevue', 'WA', '98004', 47.6146, -122.1920, 4.30, 'Sichuan specialist with bold flavors, generous portions, and an authentically spicy menu.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:30"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

-- === INDIAN (5) ===
('b0000000-0000-0000-0000-000000000029', 'Kanishka Cuisine of India', 'Indian', 2, '252 Redmond Way', 'Redmond', 'WA', '98052', 47.6740, -122.1230, 4.30, 'Award-winning Indian restaurant with a tandoor oven and rich North Indian curries.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:30","close":"22:00"},"sun":{"open":"11:30","close":"21:30"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000030', 'Mayuri Indian Cuisine', 'Indian', 2, '15400 NE 20th St', 'Bellevue', 'WA', '98007', 47.6300, -122.1420, 4.10, 'Popular South Indian restaurant with dosas, biryanis, and a weekend buffet.',
 '{"mon":{"open":"11:30","close":"21:30"},"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:30"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000031', 'Bengal Tiger', 'Indian', 3, '827 Bellevue Way NE', 'Bellevue', 'WA', '98004', 47.6170, -122.2005, 4.40, 'Upscale Indian dining with refined takes on classic dishes and an elegant setting.',
 '{"mon":{"open":"11:30","close":"21:30"},"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"11:30","close":"22:00"},"sun":{"open":"11:30","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000032', 'Spice Route', 'Indian', 2, '16545 Redmond Way', 'Redmond', 'WA', '98052', 47.6730, -122.1260, 4.00, 'Casual Indian eatery with a wide range of curries, naan breads, and thali platters.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:30"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000033', 'Naan N Curry', 'Indian', 1, '8105 161st Ave NE #200', 'Redmond', 'WA', '98052', 47.6515, -122.1280, 3.90, 'Quick-service Indian restaurant with freshly baked naan and flavorful curries at great prices.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

-- === THAI (4) ===
('b0000000-0000-0000-0000-000000000034', 'Thai Chef', 'Thai', 2, '14115 NE 20th St', 'Bellevue', 'WA', '98007', 47.6295, -122.1480, 4.20, 'Family-run Thai restaurant with authentic recipes, generous portions, and a warm atmosphere.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:30","close":"21:30"},"sun":{"open":"11:30","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000035', 'Typhoon! Bellevue', 'Thai', 2, '600 Bellevue Way NE', 'Bellevue', 'WA', '98004', 47.6160, -122.2005, 4.10, 'Stylish Thai restaurant with creative cocktails and contemporary takes on Thai classics.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000036', 'Thai Ginger', 'Thai', 2, '16480 NE 74th St', 'Redmond', 'WA', '98052', 47.6670, -122.1280, 4.00, 'Popular Pacific Northwest Thai chain known for curries, pad thai, and a family-friendly vibe.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000037', 'Bai Tong Thai', 'Thai', 3, '14804 NE 24th St', 'Bellevue', 'WA', '98007', 47.6310, -122.1450, 4.40, 'Upscale Thai dining with elegant presentation, signature curries, and an extensive menu.',
 '{"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"12:00","close":"22:00"},"sun":{"open":"12:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

-- === VIETNAMESE (4) ===
('b0000000-0000-0000-0000-000000000038', 'Monsoon Bellevue', 'Vietnamese', 3, '10245 Main St #100', 'Bellevue', 'WA', '98004', 47.6132, -122.1990, 4.50, 'Contemporary Vietnamese cuisine with French influences, local ingredients, and an elegant dining room.',
 '{"tue":{"open":"17:00","close":"22:00"},"wed":{"open":"17:00","close":"22:00"},"thu":{"open":"17:00","close":"22:00"},"fri":{"open":"17:00","close":"22:30"},"sat":{"open":"17:00","close":"22:30"},"sun":{"open":"17:00","close":"21:30"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000039', 'Pho Bel-Red', 'Vietnamese', 1, '15005 NE 24th St #A', 'Redmond', 'WA', '98052', 47.6312, -122.1443, 4.20, 'No-frills pho house with rich, slow-simmered broths and generous bowls at wallet-friendly prices.',
 '{"mon":{"open":"10:00","close":"21:00"},"tue":{"open":"10:00","close":"21:00"},"wed":{"open":"10:00","close":"21:00"},"thu":{"open":"10:00","close":"21:00"},"fri":{"open":"10:00","close":"21:30"},"sat":{"open":"10:00","close":"21:30"},"sun":{"open":"10:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000040', 'Pho Hoa', 'Vietnamese', 1, '15600 NE 8th St #O-2', 'Bellevue', 'WA', '98008', 47.6165, -122.1370, 3.90, 'Reliable pho chain with classic Vietnamese soups, spring rolls, and banh mi.',
 '{"mon":{"open":"10:00","close":"21:00"},"tue":{"open":"10:00","close":"21:00"},"wed":{"open":"10:00","close":"21:00"},"thu":{"open":"10:00","close":"21:00"},"fri":{"open":"10:00","close":"21:30"},"sat":{"open":"10:00","close":"21:30"},"sun":{"open":"10:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000041', 'Ba Bar Bellevue', 'Vietnamese', 2, '555 108th Ave NE', 'Bellevue', 'WA', '98004', 47.6155, -122.1950, 4.30, 'Hip Vietnamese street food restaurant with craft cocktails, pho, and banh mi.',
 '{"mon":{"open":"11:00","close":"22:00"},"tue":{"open":"11:00","close":"22:00"},"wed":{"open":"11:00","close":"22:00"},"thu":{"open":"11:00","close":"22:00"},"fri":{"open":"11:00","close":"23:00"},"sat":{"open":"10:00","close":"23:00"},"sun":{"open":"10:00","close":"22:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

-- === MEXICAN (4) ===
('b0000000-0000-0000-0000-000000000042', 'Cactus Bellevue', 'Mexican', 2, '460 106th Ave NE', 'Bellevue', 'WA', '98004', 47.6150, -122.1965, 4.10, 'Southwestern-inspired restaurant with creative tacos, enchiladas, and margaritas.',
 '{"mon":{"open":"11:00","close":"22:00"},"tue":{"open":"11:00","close":"22:00"},"wed":{"open":"11:00","close":"22:00"},"thu":{"open":"11:00","close":"22:00"},"fri":{"open":"11:00","close":"23:00"},"sat":{"open":"10:00","close":"23:00"},"sun":{"open":"10:00","close":"22:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000043', 'Agave Cocina & Tequila', 'Mexican', 2, '700 Bellevue Way NE #160', 'Bellevue', 'WA', '98004', 47.6168, -122.2012, 4.20, 'Vibrant Mexican cantina with 200+ tequilas, fresh guacamole, and sizzling fajitas.',
 '{"mon":{"open":"11:00","close":"22:00"},"tue":{"open":"11:00","close":"22:00"},"wed":{"open":"11:00","close":"22:00"},"thu":{"open":"11:00","close":"22:00"},"fri":{"open":"11:00","close":"23:00"},"sat":{"open":"11:00","close":"23:00"},"sun":{"open":"11:00","close":"22:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000044', 'Mi Casa Mexican', 'Mexican', 1, '15230 NE 24th St #100', 'Redmond', 'WA', '98052', 47.6314, -122.1428, 3.90, 'Casual, family-owned Mexican restaurant with generous burritos and authentic tacos al pastor.',
 '{"mon":{"open":"10:00","close":"21:00"},"tue":{"open":"10:00","close":"21:00"},"wed":{"open":"10:00","close":"21:00"},"thu":{"open":"10:00","close":"21:00"},"fri":{"open":"10:00","close":"22:00"},"sat":{"open":"10:00","close":"22:00"},"sun":{"open":"10:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000045', 'Ocho Rios Latin Cuisine', 'Mexican', 2, '16564 Cleveland St #106', 'Redmond', 'WA', '98052', 47.6732, -122.1253, 4.10, 'Latin fusion with Mexican, Salvadoran, and Caribbean flavors in downtown Redmond.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

-- === SEAFOOD (4) ===
('b0000000-0000-0000-0000-000000000046', 'The Crab Pot', 'Seafood', 3, '10246 NE 10th St', 'Bellevue', 'WA', '98004', 47.6165, -122.1985, 4.20, 'Seafood feast house known for its signature Seafeast — buckets of crab, shrimp, and clams.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000047', 'Blue Fish Sushi & Seafood', 'Seafood', 2, '15600 NE 8th St #O-7', 'Bellevue', 'WA', '98008', 47.6168, -122.1375, 4.00, 'Casual seafood spot with sushi, grilled fish, and a popular happy hour.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000048', 'Anthony''s HomePort', 'Seafood', 3, '135 Lake St S', 'Kirkland', 'WA', '98033', 47.6763, -122.2064, 4.30, 'Pacific Northwest seafood institution with waterfront dining, fresh oysters, and seasonal catches.',
 '{"mon":{"open":"11:30","close":"21:30"},"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000061', 'Seastar Restaurant & Raw Bar', 'Seafood', 4, '205 108th Ave NE', 'Bellevue', 'WA', '98004', 47.6158, -122.1955, 4.60, 'Premier Bellevue seafood destination featuring an acclaimed raw bar, sustainably sourced fish, and creative Pacific Northwest preparations in a sleek, modern setting.',
 '{"mon":{"open":"11:30","close":"22:00"},"tue":{"open":"11:30","close":"22:00"},"wed":{"open":"11:30","close":"22:00"},"thu":{"open":"11:30","close":"22:00"},"fri":{"open":"11:30","close":"23:00"},"sat":{"open":"11:00","close":"23:00"},"sun":{"open":"11:00","close":"21:30"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

-- === FRENCH (3) ===
('b0000000-0000-0000-0000-000000000049', 'Mistral Kitchen', 'French', 4, '10253 Main St', 'Bellevue', 'WA', '98004', 47.6134, -122.1993, 4.60, 'Chef-driven French-inspired cuisine with Pacific NW ingredients, an open kitchen, and artisan cocktails.',
 '{"tue":{"open":"17:00","close":"22:00"},"wed":{"open":"17:00","close":"22:00"},"thu":{"open":"17:00","close":"22:00"},"fri":{"open":"17:00","close":"23:00"},"sat":{"open":"17:00","close":"23:00"},"sun":{"open":"17:00","close":"21:00"}}',
 '{"wifi": false, "outdoor_seating": false, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000050', 'Café Juanita', 'French', 4, '9702 NE 120th Pl', 'Kirkland', 'WA', '98034', 47.7025, -122.1880, 4.70, 'Northern Italian-French fusion in a charming Kirkland cottage. Seasonal tasting menus and exceptional wines.',
 '{"tue":{"open":"17:00","close":"21:30"},"wed":{"open":"17:00","close":"21:30"},"thu":{"open":"17:00","close":"21:30"},"fri":{"open":"17:00","close":"22:00"},"sat":{"open":"17:00","close":"22:00"}}',
 '{"wifi": false, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": false}'),

('b0000000-0000-0000-0000-000000000051', 'Le Grand Bistro', 'French', 3, '11100 NE 6th St', 'Bellevue', 'WA', '98004', 47.6149, -122.1880, 4.30, 'Classic French bistro with steak frites, duck confit, and an impressive cheese selection.',
 '{"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

-- === MEDITERRANEAN (3) ===
('b0000000-0000-0000-0000-000000000052', 'Oren''s Hummus', 'Mediterranean', 2, '10245 Main St #200', 'Bellevue', 'WA', '98004', 47.6131, -122.1988, 4.30, 'Israeli-Mediterranean restaurant with freshly made hummus, falafel, and shawarma.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000053', 'Hearth & Vine', 'Mediterranean', 3, '800 Bellevue Way NE', 'Bellevue', 'WA', '98004', 47.6172, -122.2010, 4.40, 'Mediterranean-inspired restaurant with wood-fired dishes, craft wines, and a sun-lit terrace.',
 '{"mon":{"open":"11:30","close":"21:30"},"tue":{"open":"11:30","close":"21:30"},"wed":{"open":"11:30","close":"21:30"},"thu":{"open":"11:30","close":"21:30"},"fri":{"open":"11:30","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": true, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000054', 'Olive & Vine', 'Mediterranean', 2, '16575 NE 74th St', 'Redmond', 'WA', '98052', 47.6668, -122.1282, 4.10, 'Casual Mediterranean grill with kebabs, mezze platters, and warm pita bread.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

-- === BBQ (3) ===
('b0000000-0000-0000-0000-000000000055', 'Jack''s BBQ Bellevue', 'BBQ', 2, '10116 NE 8th St', 'Bellevue', 'WA', '98004', 47.6155, -122.2020, 4.40, 'Texas-style BBQ with smoked brisket, ribs, and pulled pork. Long lines and worth the wait.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000056', 'Pig Iron BBQ', 'BBQ', 2, '15600 NE 8th St #J-6', 'Bellevue', 'WA', '98008', 47.6163, -122.1368, 4.10, 'Carolina-style BBQ with tangy vinegar sauces, smoky ribs, and scratch-made sides.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"21:30"},"sat":{"open":"11:00","close":"21:30"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": false, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000057', 'Woodhouse BBQ', 'BBQ', 1, '16515 Cleveland St', 'Redmond', 'WA', '98052', 47.6733, -122.1248, 4.00, 'No-frills BBQ joint with massive portions of smoked meats and homestyle sides.',
 '{"mon":{"open":"11:00","close":"20:30"},"tue":{"open":"11:00","close":"20:30"},"wed":{"open":"11:00","close":"20:30"},"thu":{"open":"11:00","close":"20:30"},"fri":{"open":"11:00","close":"21:00"},"sat":{"open":"11:00","close":"21:00"},"sun":{"open":"11:00","close":"20:30"}}',
 '{"wifi": false, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

-- === PIZZA (3) ===
('b0000000-0000-0000-0000-000000000058', 'MOD Pizza Bellevue', 'Pizza', 1, '400 108th Ave NE', 'Bellevue', 'WA', '98004', 47.6148, -122.1955, 3.80, 'Build-your-own artisan pizza with unlimited toppings and a fast-casual vibe.',
 '{"mon":{"open":"10:30","close":"22:00"},"tue":{"open":"10:30","close":"22:00"},"wed":{"open":"10:30","close":"22:00"},"thu":{"open":"10:30","close":"22:00"},"fri":{"open":"10:30","close":"23:00"},"sat":{"open":"10:30","close":"23:00"},"sun":{"open":"10:30","close":"22:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000059', 'Tutta Bella Neapolitan Pizzeria', 'Pizza', 2, '15600 NE 8th St #O-1', 'Bellevue', 'WA', '98008', 47.6166, -122.1372, 4.20, 'Certified Neapolitan pizzeria with imported Italian ingredients and a wood-fired oven.',
 '{"mon":{"open":"11:00","close":"21:30"},"tue":{"open":"11:00","close":"21:30"},"wed":{"open":"11:00","close":"21:30"},"thu":{"open":"11:00","close":"21:30"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}'),

('b0000000-0000-0000-0000-000000000060', 'Zeeks Pizza Redmond', 'Pizza', 1, '8012 161st Ave NE', 'Redmond', 'WA', '98052', 47.6518, -122.1282, 4.00, 'Local PNW pizza chain with creative specialty pies and a fun, laid-back atmosphere.',
 '{"mon":{"open":"11:00","close":"21:00"},"tue":{"open":"11:00","close":"21:00"},"wed":{"open":"11:00","close":"21:00"},"thu":{"open":"11:00","close":"21:00"},"fri":{"open":"11:00","close":"22:00"},"sat":{"open":"11:00","close":"22:00"},"sun":{"open":"11:00","close":"21:00"}}',
 '{"wifi": true, "outdoor_seating": true, "private_dining": false, "wheelchair_accessible": true}');


-- ===== TABLE GROUPS (2-3 per restaurant) =====
-- Generate table groups programmatically
DO $$
DECLARE
    r RECORD;
    group_counter INT := 0;
    has_private BOOLEAN;
    has_patio BOOLEAN;
BEGIN
    FOR r IN SELECT restaurant_id, name, price_level, amenities FROM restaurants ORDER BY restaurant_id LOOP
        group_counter := group_counter + 1;
        has_patio := (r.amenities::jsonb->>'outdoor_seating')::boolean;
        has_private := (r.amenities::jsonb->>'private_dining')::boolean;

        -- Every restaurant gets a Main Dining group
        INSERT INTO table_groups (table_group_id, restaurant_id, name, attributes, pricing, display_order) VALUES
            (uuid_generate_v4(), r.restaurant_id, 'Main Dining', '{"indoor": true}', '{"base_multiplier": 1.0}', 1);

        -- Restaurants with outdoor seating get a Patio group
        IF has_patio THEN
            INSERT INTO table_groups (table_group_id, restaurant_id, name, attributes, pricing, display_order) VALUES
                (uuid_generate_v4(), r.restaurant_id, 'Patio', '{"outdoor": true}', '{"base_multiplier": 1.1}', 2);
        END IF;

        -- Restaurants with private dining get a Private Room
        IF has_private AND r.price_level >= 3 THEN
            INSERT INTO table_groups (table_group_id, restaurant_id, name, attributes, pricing, display_order) VALUES
                (uuid_generate_v4(), r.restaurant_id, 'Private Room', '{"private": true}', '{"base_multiplier": 1.5}', 3);
        END IF;

        -- Korean BBQ restaurants get a BBQ Grill Seating group
        IF r.name ILIKE '%bbq%' OR r.name ILIKE '%Korean BBQ%' THEN
            INSERT INTO table_groups (table_group_id, restaurant_id, name, attributes, pricing, display_order) VALUES
                (uuid_generate_v4(), r.restaurant_id, 'BBQ Grill Seating', '{"grill_table": true}', '{"base_multiplier": 1.2}', 2)
            ON CONFLICT (restaurant_id, name) DO NOTHING;
        END IF;
    END LOOP;
END $$;

-- Seastar gets a Bar group (not auto-generated)
INSERT INTO table_groups (table_group_id, restaurant_id, name, attributes, pricing, display_order) VALUES
    (uuid_generate_v4(), 'b0000000-0000-0000-0000-000000000061', 'Bar', '{"bar_seating": true}', '{"base_multiplier": 1.0}', 2);


-- ===== TABLES (3-6 per restaurant) =====
DO $$
DECLARE
    r RECORD;
    g RECORD;
    tbl_num INT;
    cap INT;
    min_cap INT;
    tbl_prefix TEXT;
    group_count INT;
BEGIN
    FOR r IN SELECT restaurant_id FROM restaurants ORDER BY restaurant_id LOOP
        tbl_num := 0;
        FOR g IN SELECT table_group_id, name, display_order FROM table_groups WHERE restaurant_id = r.restaurant_id ORDER BY display_order LOOP
            group_count := CASE
                WHEN g.name = 'Main Dining' THEN 4
                WHEN g.name = 'Patio' THEN 2
                WHEN g.name = 'Private Room' THEN 1
                WHEN g.name = 'BBQ Grill Seating' THEN 3
                WHEN g.name = 'Bar' THEN 4
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

            FOR i IN 1..group_count LOOP
                tbl_num := tbl_num + 1;
                -- Vary capacity: small (2), medium (4), large (6), extra (8/10)
                cap := CASE
                    WHEN g.name = 'Private Room' THEN 10
                    WHEN g.name = 'Bar' AND i <= 3 THEN 2
                    WHEN g.name = 'Bar' AND i = 4 THEN 4
                    WHEN i = 1 THEN 2
                    WHEN i = 2 THEN 4
                    WHEN i = 3 THEN 4
                    WHEN i = 4 THEN 6
                    ELSE 2
                END;
                min_cap := CASE
                    WHEN cap <= 2 THEN 1
                    WHEN cap <= 4 THEN 2
                    WHEN cap <= 6 THEN 3
                    ELSE 4
                END;

                INSERT INTO tables (table_id, restaurant_id, table_group_id, table_number, capacity, min_capacity, attributes) VALUES
                    (uuid_generate_v4(), r.restaurant_id, g.table_group_id, tbl_prefix || tbl_num, cap, min_cap, '{}');
            END LOOP;
        END LOOP;
    END LOOP;
END $$;


-- ===== GENERATE TIME SLOTS (next 30 days for all restaurants) =====
-- Use INSERT...SELECT for bulk performance instead of nested PL/pgSQL loops
INSERT INTO time_slots (restaurant_id, table_id, table_group_id, start_time, end_time, status, capacity)
SELECT
    t.restaurant_id,
    t.table_id,
    t.table_group_id,
    d.day + s.slot_time AS start_time,
    d.day + s.slot_time + INTERVAL '90 minutes' AS end_time,
    'AVAILABLE',
    t.capacity
FROM tables t
CROSS JOIN generate_series(CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days', '1 day'::interval) AS d(day)
CROSS JOIN (
    SELECT (INTERVAL '11 hours' + (n * INTERVAL '90 minutes'))::time AS slot_time
    FROM generate_series(0, 6) AS n  -- 11:00, 12:30, 14:00, 15:30, 17:00, 18:30, 20:00
) AS s
ON CONFLICT (restaurant_id, table_id, start_time) DO NOTHING;


-- ===== DEFAULT POLICIES =====
-- Fine dining restaurants get stricter policies
INSERT INTO restaurant_policies (restaurant_id, policy_type, time_range, rules, priority)
SELECT restaurant_id, 'hold_duration', 'default', '{"seconds": 300}', 0
FROM restaurants WHERE price_level >= 3;

INSERT INTO restaurant_policies (restaurant_id, policy_type, time_range, rules, priority)
SELECT restaurant_id, 'hold_duration', 'T-24h', '{"seconds": 120}', 10
FROM restaurants WHERE price_level >= 3;

INSERT INTO restaurant_policies (restaurant_id, policy_type, time_range, rules, priority)
SELECT restaurant_id, 'hold_duration', 'T-6h', '{"seconds": 0}', 20
FROM restaurants WHERE price_level >= 4;

INSERT INTO restaurant_policies (restaurant_id, policy_type, time_range, rules, priority)
SELECT restaurant_id, 'cancellation_fee', 'default', '{"percentage": 0}', 0
FROM restaurants WHERE price_level >= 3;

INSERT INTO restaurant_policies (restaurant_id, policy_type, time_range, rules, priority)
SELECT restaurant_id, 'cancellation_fee', 'T-48h', '{"percentage": 50}', 10
FROM restaurants WHERE price_level >= 3;

INSERT INTO restaurant_policies (restaurant_id, policy_type, time_range, rules, priority)
SELECT restaurant_id, 'cancellation_fee', 'T-24h', '{"percentage": 100}', 20
FROM restaurants WHERE price_level >= 4;


DO $$
DECLARE
    rest_count INT;
    tbl_count INT;
    group_count INT;
BEGIN
    SELECT COUNT(*) INTO rest_count FROM restaurants;
    SELECT COUNT(*) INTO tbl_count FROM tables;
    SELECT COUNT(*) INTO group_count FROM table_groups;
    RAISE NOTICE '[OK] Seed data loaded: 5 users, % restaurants, % table groups, % tables, time slots for 30 days', rest_count, group_count, tbl_count;
END $$;
