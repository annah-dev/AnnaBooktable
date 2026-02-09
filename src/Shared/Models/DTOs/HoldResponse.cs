namespace AnnaBooktable.Shared.Models.DTOs;

public class HoldResponse
{
    public string HoldToken { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public Guid SlotId { get; set; }
}
