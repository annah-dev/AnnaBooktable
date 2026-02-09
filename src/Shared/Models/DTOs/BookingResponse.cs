namespace AnnaBooktable.Shared.Models.DTOs;

public class BookingResponse
{
    public Guid ReservationId { get; set; }
    public string ConfirmationCode { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string RestaurantName { get; set; } = string.Empty;
    public DateTime DateTime { get; set; }
    public int PartySize { get; set; }
}
