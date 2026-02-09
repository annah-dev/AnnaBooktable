using System.ComponentModel.DataAnnotations;

namespace AnnaBooktable.Shared.Models.Entities;

public class TableGroup
{
    public Guid TableGroupId { get; set; }

    public Guid RestaurantId { get; set; }

    [Required, MaxLength(50)]
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string Attributes { get; set; } = "{}";
    public string Pricing { get; set; } = "{\"base_multiplier\": 1.0}";

    public int DisplayOrder { get; set; }

    // Navigation properties
    public Restaurant Restaurant { get; set; } = null!;
    public ICollection<DiningTable> Tables { get; set; } = new List<DiningTable>();
    public ICollection<TimeSlot> TimeSlots { get; set; } = new List<TimeSlot>();
}
