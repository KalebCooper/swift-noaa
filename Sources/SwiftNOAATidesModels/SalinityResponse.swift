/// An independently decodable salinity wire response.
public struct SalinityResponse: Codable, Hashable, Sendable {
  /// Station metadata actually echoed by NOAA.
  public let metadata: CoastalDataMetadata
  /// Required observations in provider order, preserving empty success and missing samples.
  public let observations: [SalinityObservation]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
