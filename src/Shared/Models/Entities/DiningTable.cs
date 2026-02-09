using System.ComponentModel.DataAnnotations;

namespace AnnaBooktable.Shared.Models.Entities;

/// <summary>
/// Maps to the "tables" PostgreSQL table. Named DiningTable to avoid conflict with System.Data.DataTable.
/// </summary>
public class DiningTable
{
    public Guid TableId { get; set; }

    public Guid RestaurantId { get; set; }

    public Guid? TableGroupId { get; set; }

    [Required, MaxLength(10)]
    public string TableNumber { get; set; } = string.Empty;

    public int Capacity { get; set; }

    public int MinCapacity { get; set; } = 1;

    public string Attributes { get; set; } = "{}";

    [MaxLength(20)]
    public string Status { get; set; } = "ACTIVE";

    // Navigation properties
    public Restaurant Restaurant { get; set; } = null!;
    public TableGroup? TableGroup { get; set; }
    public ICollection<TimeSlot> TimeSlots { get; set; } = new List<TimeSlot>();
}
