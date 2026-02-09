namespace AnnaBooktable.Shared.Models.DTOs;

public class BookingRequest
{
    public Guid SlotId { get; set; }
    public Guid UserId { get; set; }
    public string? HoldToken { get; set; }
    public int PartySize { get; set; }
    public string? SpecialRequests { get; set; }
    public string? PaymentToken { get; set; }
    public string? IdempotencyKey { get; set; }
}
