/// One six-minute measured water-level observation, distinct from a prediction.
///
/// Quality comes from NOAA, never the sample's age. Missing numeric text stays observable.
public struct WaterLevel: Codable, Hashable, Sendable {
  /// Raw comma-separated flags in provider order.
  ///
  /// Preliminary fields are outlier count, flat tolerance, rate tolerance and level limit.
  /// Verified fields are inferred value, flat tolerance, rate tolerance and level limit.
  /// Interpret the first field with `quality`; unknown codes and flag text remain unchanged.
  public let flags: String
  /// Measured height in the requested datum and units, or explicit missing text.
  public let height: TidesMeasurementValue
  /// The provider's preliminary, verified, or future quality code.
  public let quality: WaterLevelQuality
  /// Standard deviation of the one-second samples, with empty text meaning missing.
  public let sigma: TidesMeasurementValue
  /// The observation's GMT minute.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case height = "v"
    case quality = "q"
    case sigma = "s"
    case time = "t"
  }
}
