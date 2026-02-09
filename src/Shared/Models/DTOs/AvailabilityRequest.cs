namespace AnnaBooktable.Shared.Models.DTOs;

public class AvailabilityRequest
{
    public Guid RestaurantId { get; set; }
    public DateOnly Date { get; set; }
    public int PartySize { get; set; }
    public Guid? TableGroupId { get; set; }
}
