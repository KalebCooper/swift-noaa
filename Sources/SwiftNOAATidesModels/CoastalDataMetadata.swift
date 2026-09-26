/// Station metadata echoed by a CO-OPS observation response.
///
/// These values are provider-reported. Requested units and datum remain in the client's query context.
public struct CoastalDataMetadata: Codable, Hashable, Sendable {
  /// The provider's station identifier without case normalization.
  public let identifier: String
  /// Latitude in decimal degrees, retaining the original numeric string.
  public let latitude: TidesNumericValue
  /// Longitude in decimal degrees, retaining the original numeric string.
  public let longitude: TidesNumericValue
  /// The provider's station name, including any literal placeholder text.
  public let name: String

  private enum CodingKeys: String, CodingKey {
    case identifier = "id"
    case latitude = "lat"
    case longitude = "lon"
    case name
  }
}
