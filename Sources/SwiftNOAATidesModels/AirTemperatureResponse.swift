/// An independently decodable air temperature wire response.
public struct AirTemperatureResponse: Codable, Hashable, Sendable {
  /// Station metadata actually echoed by NOAA.
  public let metadata: CoastalDataMetadata
  /// Required observations in provider order, preserving empty success and missing samples.
  public let observations: [AirTemperatureObservation]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
