namespace AnnaBooktable.Shared.Events;

public record SlotHeld
{
    public Guid SlotId { get; init; }
    public Guid UserId { get; init; }
    public DateTime ExpiresAt { get; init; }
}
