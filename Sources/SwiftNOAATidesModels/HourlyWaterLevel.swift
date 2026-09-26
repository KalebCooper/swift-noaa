/// One observation from NOAA's verified hourly-height product.
///
/// This product has its own flag meanings and does not echo the six-minute quality code.
public struct HourlyWaterLevel: Codable, Hashable, Sendable {
  /// Raw comma-separated flags: inferred value, then expected level limit exceeded.
  /// Unknown or additional flag text is retained without interpretation.
  public let flags: String
  /// Measured height in requested units and datum, preserving missing text.
  public let height: TidesMeasurementValue
  /// Reported standard deviation, preserving missing text.
  public let sigma: TidesMeasurementValue
  /// The reported GMT minute, without local-time assumptions.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case height = "v"
    case sigma = "s"
    case time = "t"
  }
}
