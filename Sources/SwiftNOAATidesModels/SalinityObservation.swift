/// One salinity sample with its independently reported specific gravity.
public struct SalinityObservation: Codable, Hashable, Sendable {
  /// Practical salinity units in either requested unit system; empty text is missing.
  public let salinity: TidesMeasurementValue
  /// Dimensionless specific gravity in either unit system; never calculated from salinity.
  public let specificGravity: TidesMeasurementValue
  /// Exact observation time in GMT.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case salinity = "s"
    case specificGravity = "g"
    case time = "t"
  }
}
