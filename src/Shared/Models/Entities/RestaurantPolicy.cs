using System.ComponentModel.DataAnnotations;

namespace AnnaBooktable.Shared.Models.Entities;

public class RestaurantPolicy
{
    public Guid PolicyId { get; set; }

    public Guid RestaurantId { get; set; }

    [Required, MaxLength(50)]
    public string PolicyType { get; set; } = string.Empty;

    [Required, MaxLength(20)]
    public string TimeRange { get; set; } = "default";

    [Required]
    public string Rules { get; set; } = "{}";

    public int Priority { get; set; }

    public bool Enabled { get; set; } = true;

    // Navigation properties
    public Restaurant Restaurant { get; set; } = null!;
}
