/// One reported wind sample in GMT, preserving each component independently.
public struct WindObservation: Codable, Hashable, Sendable {
  /// Raw maximum-speed and rate-of-change flags, in provider order.
  public let flags: String
  /// Reported gust speed in metric meters per second or English knots.
  public let gust: TidesMeasurementValue
  /// Direction in degrees true from which the wind blows; empty text remains missing.
  public let numericDirection: TidesMeasurementValue
  /// Reported wind speed in metric meters per second or English knots.
  public let speed: TidesMeasurementValue
  /// Provider compass text, including empty or unfamiliar values; never derived from degrees.
  public let textDirection: String
  /// Exact observation time in GMT.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case gust = "g"
    case numericDirection = "d"
    case speed = "s"
    case textDirection = "dr"
    case time = "t"
  }
}
