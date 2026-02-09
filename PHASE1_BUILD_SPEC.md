# Phase 1 Build Spec: Microservices API Implementation

## Project Location
D:\Dev\AnnaBooktable

## Existing Infrastructure
- PostgreSQL on localhost:5432 (user: booktable_admin, pass: LocalDev123!, db: booktable)
- Redis on localhost:6379
- Elasticsearch on localhost:9200
- RabbitMQ on localhost:5672 (guest/guest)
- Schema already created (users, restaurants, table_groups, tables, time_slots, reservations, reviews, restaurant_policies)
- Seed data already loaded (10 SF restaurants, tables, time_slots, 3 test users)

## Architecture Overview
5 .NET 8 microservices + YARP Gateway, communicating via REST (sync) and RabbitMQ/MassTransit (async).

| Service | Port | Responsibility |
|---------|------|----------------|
| Gateway | 5000 | YARP reverse proxy, auth, rate limiting |
| SearchService | 5001 | Restaurant search, filtering, ranking |
| InventoryService | 5002 | Availability checks, Redis holds (Layer 1) |
| ReservationService | 5003 | Booking orchestration, DB transactions (Layer 2), idempotency (Layer 3) |
| PaymentService | 5004 | Stripe integration (test mode), deposits |

## Shared Libraries (already scaffolded)
- **AnnaBooktable.Shared.Models** - Entity classes, DTOs, enums
- **AnnaBooktable.Shared.Events** - MassTransit event contracts
- **AnnaBooktable.Shared.Infrastructure** - DbContext, Redis helpers, common middleware

## CONNECTION STRINGS (in appsettings.Development.json, already created)
```
PostgreSQL: Host=localhost;Port=5432;Database=booktable;Username=booktable_admin;Password=LocalDev123!
Redis: localhost:6379
Elasticsearch: http://localhost:9200
RabbitMQ: amqp://guest:guest@localhost:5672
```

---

## BUILD ORDER (do these in sequence)

### Step 1: Shared.Models - Entity Classes + DTOs

Create in `src/Shared/Models/`:

**Entities/ folder:**
- `User.cs` - Maps to users table
- `Restaurant.cs` - Maps to restaurants table
- `TableGroup.cs` - Maps to table_groups table
- `Table.cs` - Maps to tables table (use "DiningTable" as C# class name to avoid conflict)
- `TimeSlot.cs` - Maps to time_slots table
- `Reservation.cs` - Maps to reservations table
- `Review.cs` - Maps to reviews table
- `RestaurantPolicy.cs` - Maps to restaurant_policies table

All entities use UUID primary keys, match the PostgreSQL schema exactly.

**DTOs/ folder:**
- `SearchRequest.cs` - { Query, Cuisine, City, Date, Time, PartySize, Latitude, Longitude, Radius, Page, PageSize }
- `SearchResult.cs` - { RestaurantId, Name, Cuisine, PriceLevel, AvgRating, Distance, Address, CoverImageUrl, AvailableSlots[] }
- `AvailabilityRequest.cs` - { RestaurantId, Date, PartySize, TableGroupId? }
- `AvailabilityResponse.cs` - { RestaurantId, Date, Slots[] { SlotId, StartTime, EndTime, TableNumber, TableGroupName, Capacity } }
- `HoldRequest.cs` - { SlotId, UserId }
- `HoldResponse.cs` - { HoldToken, ExpiresAt, SlotId }
- `BookingRequest.cs` - { SlotId, UserId, HoldToken, PartySize, SpecialRequests, PaymentToken, IdempotencyKey }
- `BookingResponse.cs` - { ReservationId, ConfirmationCode, Status, RestaurantName, DateTime, PartySize }
- `ApiResponse<T>.cs` - { Success, Data, Error, Timestamp }
- `ErrorResponse.cs` - { Code, Message, Details }

**Enums/ folder:**
- `SlotStatus.cs` - Available, Held, Booked, Blocked
- `ReservationStatus.cs` - Confirmed, Cancelled, NoShow, Completed, Pending
- `PaymentStatus.cs` - None, Pending, Captured, Refunded, Failed

### Step 2: Shared.Infrastructure - DbContext + Helpers

Create in `src/Shared/Infrastructure/`:

**Data/ folder:**
- `BooktableDbContext.cs` - EF Core DbContext with all DbSets, OnModelCreating configures:
  - Table names (lowercase, matches PostgreSQL)
  - UNIQUE constraint on time_slots(restaurant_id, table_id, start_time)
  - UNIQUE constraint on reservations(slot_id) -- renamed to slot_date_key or similar
  - UNIQUE constraint on reservations(confirmation_code)
  - All indexes matching the SQL schema
  - Column mappings for snake_case (use .ToTable("time_slots"), .Property(x => x.SlotId).HasColumnName("slot_id"), etc.)

**Redis/ folder:**
- `RedisService.cs` - Wrapper around StackExchange.Redis with methods:
  - `TryAcquireHold(slotId, userId, ttlSeconds)` -> returns (bool success, string holdToken)
  - `ValidateHold(slotId, holdToken)` -> bool
  - `ReleaseHold(slotId)` -> void
  - `GetCachedAvailability(restaurantId, date)` -> cached slots or null
  - `SetCachedAvailability(restaurantId, date, slots, ttlSeconds)` -> void
  - `CheckIdempotencyKey(key)` -> cached response or null
  - `SetIdempotencyKey(key, response, ttlSeconds)` -> void
  - Uses SETNX for holds (atomic set-if-not-exists)
  - Hold key format: `hold:{slotId}` with value `{userId}:{holdToken}`
  - Idempotency key format: `idem:{key}` with JSON serialized response
  - Availability cache key: `avail:{restaurantId}:{date}`

**Middleware/ folder:**
- `ExceptionHandlingMiddleware.cs` - Global exception handler, returns ApiResponse with proper HTTP codes
- `RequestLoggingMiddleware.cs` - Logs request/response with correlation IDs

**Extensions/ folder:**
- `ServiceCollectionExtensions.cs` - AddBooktableDbContext(), AddRedisService(), AddBooktableMiddleware()

### Step 3: Shared.Events - MassTransit Event Contracts

Create in `src/Shared/Events/`:
- `ReservationCreated.cs` - { ReservationId, UserId, RestaurantId, SlotId, ConfirmationCode, DateTime, PartySize }
- `ReservationCancelled.cs` - { ReservationId, UserId, RestaurantId, SlotId, Reason }
- `SlotHeld.cs` - { SlotId, UserId, ExpiresAt }
- `SlotReleased.cs` - { SlotId, Reason }

### Step 4: SearchService (port 5001)

**Endpoints:**
- `GET /api/search?query=sushi&city=SF&date=2026-02-10&time=19:00&partySize=2&page=1&pageSize=25`
  - For MVP: Query PostgreSQL directly (skip Elasticsearch for now)
  - Filter by cuisine, city, price_level, availability
  - Sort by avg_rating DESC, distance (if lat/lng provided)
  - Join with time_slots to check availability for requested date/time/party_size
  - Return SearchResult[] with available slot counts

- `GET /api/search/restaurants/{id}` - Restaurant detail with all info

**Implementation:**
- Use EF Core to query PostgreSQL
- Pagination with OFFSET/LIMIT
- Distance calculation using earthdistance extension if lat/lng provided
- Cache results in Redis (60s TTL)

### Step 5: InventoryService (port 5002)

**Endpoints:**
- `GET /api/inventory/availability?restaurantId={id}&date=2026-02-10&partySize=2`
  - Check Redis cache first (95% hit rate target)
  - Fallback to PostgreSQL query
  - Return available time slots grouped by time
  - Filter by capacity >= partySize

- `POST /api/inventory/hold` - Body: { slotId, userId }
  - LAYER 1: Redis SETNX hold:{slotId} {userId}:{token} EX 300
  - If success: return holdToken + expiresAt (5 minutes)
  - If fail: return 409 Conflict "Slot already held by another diner"
  - Publish SlotHeld event via MassTransit

- `DELETE /api/inventory/hold/{slotId}` - Release hold early
  - Delete Redis key, publish SlotReleased event

- `GET /api/inventory/hold/{slotId}/validate?holdToken={token}` - Validate hold is still active
  - Check Redis key exists and matches token

**Key Logic:**
- Hold token = new GUID generated server-side
- Redis key: `hold:{slotId}` value: `{userId}:{holdToken}` TTL: 300 seconds
- SETNX is atomic - prevents race condition
- If Redis is down: return warning, allow booking without hold (graceful degradation)

### Step 6: ReservationService (port 5003)

**Endpoints:**
- `POST /api/reservations` - Create booking (THE CRITICAL PATH)
  - Header: `Idempotency-Key: {uuid}`
  - Body: BookingRequest { slotId, userId, holdToken, partySize, specialRequests, paymentToken }
  
  **Flow:**
  1. LAYER 3: Check idempotency key in Redis - if exists, return cached response
  2. Validate hold with InventoryService (HTTP call to GET /api/inventory/hold/{slotId}/validate)
  3. Call PaymentService to charge deposit (HTTP call to POST /api/payments/charge)
  4. LAYER 2: Database transaction:
     ```sql
     BEGIN;
     INSERT INTO reservations (user_id, restaurant_id, slot_id, confirmation_code, party_size, special_requests, status, deposit_amount, payment_status, payment_intent_id, idempotency_key)
     VALUES (...);
     UPDATE time_slots SET status = 'BOOKED', held_by = NULL, held_until = NULL WHERE slot_id = ? AND date = ?;
     COMMIT;
     ```
     - UNIQUE constraint on time_slots(restaurant_id, table_id, start_time) prevents double-booking
     - If constraint violation: return 409 Conflict, refund payment
  5. Cache idempotency response in Redis (24hr TTL)
  6. Release hold in Redis (cleanup)
  7. Publish ReservationCreated event via MassTransit
  8. Return BookingResponse with confirmation code

  **Confirmation code:** Generate 6-char alphanumeric (e.g., "ABC123")

- `GET /api/reservations/{id}` - Get reservation detail
- `GET /api/reservations/user/{userId}` - Get user's reservations
- `POST /api/reservations/{id}/cancel` - Cancel reservation
  - Update status, refund if applicable, release slot, publish ReservationCancelled event
- `GET /api/reservations/confirm/{confirmationCode}` - Lookup by confirmation code

### Step 7: PaymentService (port 5004)

**Endpoints:**
- `POST /api/payments/charge` - Charge deposit
  - Body: { amount, currency, paymentToken, idempotencyKey, description }
  - For MVP: Simulate Stripe (don't need real Stripe account yet)
  - Return { paymentIntentId, status, amount }
  - Always succeed in dev mode with fake payment_intent_id

- `POST /api/payments/refund` - Refund deposit
  - Body: { paymentIntentId, amount }
  - For MVP: Simulate refund
  - Return { refundId, status }

### Step 8: Gateway (port 5000)

Already configured with YARP in appsettings. Just needs:
- Add CORS for React frontend (localhost:5173)
- Add request logging middleware
- Add health check endpoint: GET /health -> { status: "healthy", services: { search: "up", inventory: "up", ... } }
- Forward /api/search/* -> SearchService:5001
- Forward /api/inventory/* -> InventoryService:5002
- Forward /api/reservations/* -> ReservationService:5003
- Forward /api/payments/* -> PaymentService:5004

---

## CRITICAL IMPLEMENTATION NOTES

1. **Defense-in-Depth is the star feature:**
   - Layer 1 (Redis holds) in InventoryService
   - Layer 2 (DB unique constraint) in ReservationService
   - Layer 3 (Idempotency) in ReservationService
   
2. **Graceful degradation:** Every Redis call must be wrapped in try/catch. If Redis is down, the system still works (just without holds/cache).

3. **All services register with MassTransit** even if they don't consume events yet. Use `AddMassTransit` with RabbitMQ transport.

4. **Each service has its own Program.cs** with minimal API style (.NET 8 minimal hosting).

5. **Use Serilog** for structured logging in all services. Already configured in appsettings.

6. **Snake_case column mapping** - PostgreSQL uses snake_case, C# uses PascalCase. Configure in DbContext.

7. **UUID primary keys** - Use Guid in C# mapped to UUID in PostgreSQL.

8. **Connection strings** are already in appsettings.Development.json for each service.

---

## TESTING THE BUILD

After implementing, verify with:

```bash
# Start infrastructure
cd D:\Dev\AnnaBooktable
.\setup-scripts\05_Dev_Helpers.ps1 start

# Build all
dotnet build

# Run all services
.\setup-scripts\05_Dev_Helpers.ps1 run-all

# Test search
curl http://localhost:5000/api/search?city=San%20Francisco&partySize=2

# Test availability
curl http://localhost:5000/api/inventory/availability?restaurantId={id}&date=2026-02-10&partySize=2

# Test hold
curl -X POST http://localhost:5000/api/inventory/hold -H "Content-Type: application/json" -d '{"slotId":"{id}","userId":"{id}"}'

# Test booking
curl -X POST http://localhost:5000/api/reservations -H "Content-Type: application/json" -H "Idempotency-Key: test-123" -d '{"slotId":"{id}","userId":"{id}","holdToken":"{token}","partySize":2}'
```
