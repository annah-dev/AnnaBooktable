namespace AnnaBooktable.Shared.Events;

public record ReservationCreated
{
    public Guid ReservationId { get; init; }
    public Guid UserId { get; init; }
    public Guid RestaurantId { get; init; }
    public Guid SlotId { get; init; }
    public string ConfirmationCode { get; init; } = string.Empty;
    public DateTime DateTime { get; init; }
    public int PartySize { get; init; }
}
