using AnnaBooktable.Shared.Models.Entities;
using Microsoft.EntityFrameworkCore;

namespace AnnaBooktable.Shared.Infrastructure.Data;

public class BooktableDbContext : DbContext
{
    public BooktableDbContext(DbContextOptions<BooktableDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Restaurant> Restaurants => Set<Restaurant>();
    public DbSet<TableGroup> TableGroups => Set<TableGroup>();
    public DbSet<DiningTable> Tables => Set<DiningTable>();
    public DbSet<TimeSlot> TimeSlots => Set<TimeSlot>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<RestaurantPolicy> RestaurantPolicies => Set<RestaurantPolicy>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ConfigureUser(modelBuilder);
        ConfigureRestaurant(modelBuilder);
        ConfigureTableGroup(modelBuilder);
        ConfigureDiningTable(modelBuilder);
        ConfigureTimeSlot(modelBuilder);
        ConfigureReservation(modelBuilder);
        ConfigureReview(modelBuilder);
        ConfigureRestaurantPolicy(modelBuilder);
    }

    private static void ConfigureUser(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("users");
            entity.HasKey(e => e.UserId);

            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Email).HasColumnName("email");
            entity.Property(e => e.PasswordHash).HasColumnName("password_hash");
            entity.Property(e => e.FirstName).HasColumnName("first_name");
            entity.Property(e => e.LastName).HasColumnName("last_name");
            entity.Property(e => e.Phone).HasColumnName("phone");
            entity.Property(e => e.Preferences).HasColumnName("preferences").HasColumnType("jsonb");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.Email).IsUnique();
        });
    }

    private static void ConfigureRestaurant(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Restaurant>(entity =>
        {
            entity.ToTable("restaurants");
            entity.HasKey(e => e.RestaurantId);

            entity.Property(e => e.RestaurantId).HasColumnName("restaurant_id");
            entity.Property(e => e.Name).HasColumnName("name");
            entity.Property(e => e.Cuisine).HasColumnName("cuisine");
            entity.Property(e => e.PriceLevel).HasColumnName("price_level");
            entity.Property(e => e.Address).HasColumnName("address");
            entity.Property(e => e.City).HasColumnName("city");
            entity.Property(e => e.State).HasColumnName("state");
            entity.Property(e => e.ZipCode).HasColumnName("zip_code");
            entity.Property(e => e.Latitude).HasColumnName("latitude").HasColumnType("decimal(10,8)");
            entity.Property(e => e.Longitude).HasColumnName("longitude").HasColumnType("decimal(11,8)");
            entity.Property(e => e.AvgRating).HasColumnName("avg_rating").HasColumnType("decimal(3,2)");
            entity.Property(e => e.TotalReviews).HasColumnName("total_reviews");
            entity.Property(e => e.OperatingHours).HasColumnName("operating_hours").HasColumnType("jsonb");
            entity.Property(e => e.Amenities).HasColumnName("amenities").HasColumnType("jsonb");
            entity.Property(e => e.Phone).HasColumnName("phone");
            entity.Property(e => e.Website).HasColumnName("website");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.CoverImageUrl).HasColumnName("cover_image_url");
            entity.Property(e => e.IsActive).HasColumnName("is_active");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.Cuisine);
            entity.HasIndex(e => e.City);
            entity.HasIndex(e => e.IsActive).HasFilter("is_active = true");
        });
    }

    private static void ConfigureTableGroup(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TableGroup>(entity =>
        {
            entity.ToTable("table_groups");
            entity.HasKey(e => e.TableGroupId);

            entity.Property(e => e.TableGroupId).HasColumnName("table_group_id");
            entity.Property(e => e.RestaurantId).HasColumnName("restaurant_id");
            entity.Property(e => e.Name).HasColumnName("name");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.Attributes).HasColumnName("attributes").HasColumnType("jsonb");
            entity.Property(e => e.Pricing).HasColumnName("pricing").HasColumnType("jsonb");
            entity.Property(e => e.DisplayOrder).HasColumnName("display_order");

            entity.HasIndex(e => e.RestaurantId);
            entity.HasIndex(e => new { e.RestaurantId, e.Name }).IsUnique();

            entity.HasOne(e => e.Restaurant)
                .WithMany(r => r.TableGroups)
                .HasForeignKey(e => e.RestaurantId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }

    private static void ConfigureDiningTable(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<DiningTable>(entity =>
        {
            entity.ToTable("tables");
            entity.HasKey(e => e.TableId);

            entity.Property(e => e.TableId).HasColumnName("table_id");
            entity.Property(e => e.RestaurantId).HasColumnName("restaurant_id");
            entity.Property(e => e.TableGroupId).HasColumnName("table_group_id");
            entity.Property(e => e.TableNumber).HasColumnName("table_number");
            entity.Property(e => e.Capacity).HasColumnName("capacity");
            entity.Property(e => e.MinCapacity).HasColumnName("min_capacity");
            entity.Property(e => e.Attributes).HasColumnName("attributes").HasColumnType("jsonb");
            entity.Property(e => e.Status).HasColumnName("status");

            entity.HasIndex(e => e.RestaurantId);
            entity.HasIndex(e => new { e.RestaurantId, e.TableGroupId });
            entity.HasIndex(e => new { e.RestaurantId, e.TableNumber }).IsUnique();

            entity.HasOne(e => e.Restaurant)
                .WithMany(r => r.Tables)
                .HasForeignKey(e => e.RestaurantId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.TableGroup)
                .WithMany(tg => tg.Tables)
                .HasForeignKey(e => e.TableGroupId)
                .OnDelete(DeleteBehavior.SetNull);
        });
    }

    private static void ConfigureTimeSlot(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TimeSlot>(entity =>
        {
            entity.ToTable("time_slots");
            // Composite PK matching partitioned table: (slot_id, date)
            entity.HasKey(e => new { e.SlotId, e.Date });

            entity.Property(e => e.SlotId).HasColumnName("slot_id");
            entity.Property(e => e.RestaurantId).HasColumnName("restaurant_id");
            entity.Property(e => e.TableId).HasColumnName("table_id");
            entity.Property(e => e.TableGroupId).HasColumnName("table_group_id");
            entity.Property(e => e.StartTime).HasColumnName("start_time");
            entity.Property(e => e.EndTime).HasColumnName("end_time");
            entity.Property(e => e.Date).HasColumnName("date")
                .ValueGeneratedOnAdd(); // Generated STORED column in PostgreSQL (part of PK, so OnAdd only)
            entity.Property(e => e.Status).HasColumnName("status");
            entity.Property(e => e.Capacity).HasColumnName("capacity");
            entity.Property(e => e.HeldBy).HasColumnName("held_by");
            entity.Property(e => e.HeldUntil).HasColumnName("held_until");

            // The critical safety net - prevents double-booking at DB level
            entity.HasIndex(e => new { e.RestaurantId, e.TableId, e.StartTime }).IsUnique();

            entity.HasIndex(e => new { e.RestaurantId, e.Date });
            entity.HasIndex(e => new { e.RestaurantId, e.Date, e.StartTime, e.Capacity })
                .HasFilter("status = 'AVAILABLE'");
            entity.HasIndex(e => new { e.RestaurantId, e.Date, e.StartTime, e.Status, e.Capacity });
            entity.HasIndex(e => new { e.TableGroupId, e.Date, e.StartTime })
                .HasFilter("table_group_id IS NOT NULL");

            entity.HasOne(e => e.Restaurant)
                .WithMany(r => r.TimeSlots)
                .HasForeignKey(e => e.RestaurantId);

            entity.HasOne(e => e.Table)
                .WithMany(t => t.TimeSlots)
                .HasForeignKey(e => e.TableId);

            entity.HasOne(e => e.TableGroup)
                .WithMany(tg => tg.TimeSlots)
                .HasForeignKey(e => e.TableGroupId);
        });
    }

    private static void ConfigureReservation(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Reservation>(entity =>
        {
            entity.ToTable("reservations");
            entity.HasKey(e => e.ReservationId);

            entity.Property(e => e.ReservationId).HasColumnName("reservation_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.RestaurantId).HasColumnName("restaurant_id");
            entity.Property(e => e.SlotId).HasColumnName("slot_id");
            entity.Property(e => e.ConfirmationCode).HasColumnName("confirmation_code");
            entity.Property(e => e.PartySize).HasColumnName("party_size");
            entity.Property(e => e.SpecialRequests).HasColumnName("special_requests");
            entity.Property(e => e.Status).HasColumnName("status");
            entity.Property(e => e.DepositAmount).HasColumnName("deposit_amount").HasColumnType("decimal(10,2)");
            entity.Property(e => e.PaymentStatus).HasColumnName("payment_status");
            entity.Property(e => e.PaymentIntentId).HasColumnName("payment_intent_id");
            entity.Property(e => e.IdempotencyKey).HasColumnName("idempotency_key");
            entity.Property(e => e.BookedAt).HasColumnName("booked_at");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            // One reservation per time slot
            entity.HasIndex(e => e.SlotId).IsUnique();
            entity.HasIndex(e => e.ConfirmationCode).IsUnique();
            entity.HasIndex(e => new { e.UserId, e.CreatedAt }).IsDescending(false, true);
            entity.HasIndex(e => new { e.RestaurantId, e.BookedAt }).IsDescending(false, true);
            entity.HasIndex(e => e.Status).HasFilter("status = 'CONFIRMED'");
            entity.HasIndex(e => e.IdempotencyKey).HasFilter("idempotency_key IS NOT NULL");

            entity.HasOne(e => e.User)
                .WithMany(u => u.Reservations)
                .HasForeignKey(e => e.UserId);

            entity.HasOne(e => e.Restaurant)
                .WithMany(r => r.Reservations)
                .HasForeignKey(e => e.RestaurantId);
        });
    }

    private static void ConfigureReview(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Review>(entity =>
        {
            entity.ToTable("reviews");
            entity.HasKey(e => e.ReviewId);

            entity.Property(e => e.ReviewId).HasColumnName("review_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.RestaurantId).HasColumnName("restaurant_id");
            entity.Property(e => e.ReservationId).HasColumnName("reservation_id");
            entity.Property(e => e.Rating).HasColumnName("rating");
            entity.Property(e => e.Comment).HasColumnName("comment");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => new { e.UserId, e.ReservationId }).IsUnique();
            entity.HasIndex(e => new { e.RestaurantId, e.CreatedAt }).IsDescending(false, true);

            entity.HasOne(e => e.User)
                .WithMany(u => u.Reviews)
                .HasForeignKey(e => e.UserId);

            entity.HasOne(e => e.Restaurant)
                .WithMany(r => r.Reviews)
                .HasForeignKey(e => e.RestaurantId);

            entity.HasOne(e => e.Reservation)
                .WithMany(r => r.Reviews)
                .HasForeignKey(e => e.ReservationId);
        });
    }

    private static void ConfigureRestaurantPolicy(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<RestaurantPolicy>(entity =>
        {
            entity.ToTable("restaurant_policies");
            entity.HasKey(e => e.PolicyId);

            entity.Property(e => e.PolicyId).HasColumnName("policy_id");
            entity.Property(e => e.RestaurantId).HasColumnName("restaurant_id");
            entity.Property(e => e.PolicyType).HasColumnName("policy_type");
            entity.Property(e => e.TimeRange).HasColumnName("time_range");
            entity.Property(e => e.Rules).HasColumnName("rules").HasColumnType("jsonb");
            entity.Property(e => e.Priority).HasColumnName("priority");
            entity.Property(e => e.Enabled).HasColumnName("enabled");

            entity.HasIndex(e => new { e.RestaurantId, e.PolicyType, e.TimeRange }).IsUnique();
            entity.HasIndex(e => new { e.RestaurantId, e.PolicyType });

            entity.HasOne(e => e.Restaurant)
                .WithMany(r => r.Policies)
                .HasForeignKey(e => e.RestaurantId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
