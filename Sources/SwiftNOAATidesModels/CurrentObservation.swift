/// One measured current at its reported bin and GMT minute.
///
/// Velocity uses requested units: centimeters per second for metric, knots for English.
/// No depth is inferred from a bin number, and absent time steps are not filled.
public struct CurrentObservation: Codable, Hashable, Sendable {
  /// The exact reported bin text, which may differ from a provider-default request.
  public let bin: String
  /// Direction in degrees, retaining empty missing text and rejecting malformed numbers.
  public let direction: TidesMeasurementValue
  /// Measured speed, retaining raw numeric or empty missing text without conversion.
  public let speed: TidesMeasurementValue
  /// The reported GMT minute.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case bin = "b"
    case direction = "d"
    case speed = "s"
    case time = "t"
  }
}
