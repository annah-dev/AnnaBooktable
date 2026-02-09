namespace AnnaBooktable.Shared.Models.DTOs;

public class SearchRequest
{
    public string? Query { get; set; }
    public string? Cuisine { get; set; }
    public string? City { get; set; }
    public DateOnly? Date { get; set; }
    public TimeOnly? Time { get; set; }
    public int? PartySize { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public double? Radius { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 25;
}
