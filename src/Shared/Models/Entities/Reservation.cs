using System.ComponentModel.DataAnnotations;

namespace AnnaBooktable.Shared.Models.Entities;

public class Reservation
{
    public Guid ReservationId { get; set; }

    public Guid UserId { get; set; }

    public Guid RestaurantId { get; set; }

    public Guid SlotId { get; set; }

    [Required, MaxLength(10)]
    public string ConfirmationCode { get; set; } = string.Empty;

    public int PartySize { get; set; }

    public string? SpecialRequests { get; set; }

    [MaxLength(20)]
    public string Status { get; set; } = "CONFIRMED";

    public decimal DepositAmount { get; set; }

    [MaxLength(20)]
    public string PaymentStatus { get; set; } = "NONE";

    [MaxLength(100)]
    public string? PaymentIntentId { get; set; }

    [MaxLength(100)]
    public string? IdempotencyKey { get; set; }

    public DateTime BookedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public Restaurant Restaurant { get; set; } = null!;
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
}
