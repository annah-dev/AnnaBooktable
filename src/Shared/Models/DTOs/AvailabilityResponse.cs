namespace AnnaBooktable.Shared.Models.DTOs;

public class AvailabilityResponse
{
    public Guid RestaurantId { get; set; }
    public DateOnly Date { get; set; }
    public AvailableSlotDetail[] Slots { get; set; } = [];
}

public class AvailableSlotDetail
{
    public Guid SlotId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public string TableNumber { get; set; } = string.Empty;
    public string? TableGroupName { get; set; }
    public int Capacity { get; set; }
}
