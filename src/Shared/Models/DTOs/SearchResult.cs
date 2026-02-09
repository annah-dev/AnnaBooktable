namespace AnnaBooktable.Shared.Models.DTOs;

public class SearchResult
{
    public Guid RestaurantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Cuisine { get; set; }
    public int? PriceLevel { get; set; }
    public decimal AvgRating { get; set; }
    public double? Distance { get; set; }
    public string? Address { get; set; }
    public string? CoverImageUrl { get; set; }
    public AvailableSlotSummary[] AvailableSlots { get; set; } = [];
}

public class AvailableSlotSummary
{
    public Guid SlotId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public int Capacity { get; set; }
    public string? TableGroupName { get; set; }
}
