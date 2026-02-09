namespace AnnaBooktable.Shared.Events;

public record SlotReleased
{
    public Guid SlotId { get; init; }
    public string? Reason { get; init; }
}
