/// An independently decodable verified observed high/low water-level response.
public struct ObservedHighLowWaterLevelResponse: Codable, Hashable, Sendable {
  /// Station metadata echoed by the provider.
  public let metadata: CoastalDataMetadata
  /// Measured observations in provider order; missing time steps are not inserted.
  public let observations: [ObservedHighLowWaterLevel]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
