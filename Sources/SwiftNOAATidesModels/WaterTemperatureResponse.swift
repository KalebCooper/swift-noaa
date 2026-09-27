/// An independently decodable water temperature wire response.
public struct WaterTemperatureResponse: Codable, Hashable, Sendable {
  /// Station metadata actually echoed by NOAA.
  public let metadata: CoastalDataMetadata
  /// Required observations in provider order, preserving empty success and missing samples.
  public let observations: [WaterTemperatureObservation]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
