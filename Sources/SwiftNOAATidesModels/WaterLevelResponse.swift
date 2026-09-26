/// An independently decodable six-minute water-level response.
public struct WaterLevelResponse: Codable, Hashable, Sendable {
  /// Station metadata echoed by the provider.
  public let metadata: CoastalDataMetadata
  /// Measured observations in provider order; missing time steps are not inserted.
  public let observations: [WaterLevel]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
