namespace AnnaBooktable.Shared.Models.Entities;

public class Review
{
    public Guid ReviewId { get; set; }

    public Guid UserId { get; set; }

    public Guid RestaurantId { get; set; }

    public Guid ReservationId { get; set; }

    public int Rating { get; set; }

    public string? Comment { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public Restaurant Restaurant { get; set; } = null!;
    public Reservation Reservation { get; set; } = null!;
}
