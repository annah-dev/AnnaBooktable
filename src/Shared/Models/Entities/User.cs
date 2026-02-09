using System.ComponentModel.DataAnnotations;

namespace AnnaBooktable.Shared.Models.Entities;

public class User
{
    public Guid UserId { get; set; }

    [Required, MaxLength(255)]
    public string Email { get; set; } = string.Empty;

    [Required, MaxLength(255)]
    public string PasswordHash { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? FirstName { get; set; }

    [MaxLength(100)]
    public string? LastName { get; set; }

    [MaxLength(20)]
    public string? Phone { get; set; }

    public string Preferences { get; set; } = "{}";

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
}
