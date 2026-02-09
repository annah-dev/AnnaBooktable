namespace AnnaBooktable.Shared.Events;

public record ReservationCancelled
{
    public Guid ReservationId { get; init; }
    public Guid UserId { get; init; }
    public Guid RestaurantId { get; init; }
    public Guid SlotId { get; init; }
    public string? Reason { get; init; }
}
