using System.ComponentModel.DataAnnotations;

namespace AnnaBooktable.Shared.Models.Entities;

public class Restaurant
{
    public Guid RestaurantId { get; set; }

    [Required, MaxLength(255)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(50)]
    public string? Cuisine { get; set; }

    public int? PriceLevel { get; set; }

    public string? Address { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(50)]
    public string? State { get; set; }

    [MaxLength(20)]
    public string? ZipCode { get; set; }

    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    public decimal AvgRating { get; set; }
    public int TotalReviews { get; set; }

    public string OperatingHours { get; set; } = "{}";
    public string Amenities { get; set; } = "{}";

    [MaxLength(20)]
    public string? Phone { get; set; }

    [MaxLength(255)]
    public string? Website { get; set; }

    public string? Description { get; set; }

    [MaxLength(500)]
    public string? CoverImageUrl { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public ICollection<TableGroup> TableGroups { get; set; } = new List<TableGroup>();
    public ICollection<DiningTable> Tables { get; set; } = new List<DiningTable>();
    public ICollection<TimeSlot> TimeSlots { get; set; } = new List<TimeSlot>();
    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
    public ICollection<RestaurantPolicy> Policies { get; set; } = new List<RestaurantPolicy>();
}
