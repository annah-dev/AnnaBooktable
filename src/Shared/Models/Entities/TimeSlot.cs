namespace AnnaBooktable.Shared.Models.Entities;

public class TimeSlot
{
    public Guid SlotId { get; set; }

    public Guid RestaurantId { get; set; }

    public Guid TableId { get; set; }

    public Guid? TableGroupId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    /// <summary>
    /// Generated column in PostgreSQL (start_time::date). Read-only in EF Core.
    /// </summary>
    public DateOnly Date { get; set; }

    public string Status { get; set; } = "AVAILABLE";

    public int Capacity { get; set; }

    public Guid? HeldBy { get; set; }

    public DateTime? HeldUntil { get; set; }

    // Navigation properties
    public Restaurant Restaurant { get; set; } = null!;
    public DiningTable Table { get; set; } = null!;
    public TableGroup? TableGroup { get; set; }
}
