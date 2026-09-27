/// A provider-verified observed extremum, distinct from a predicted tide event.
/// Verification and event availability are controlled by NOAA, not inferred from the event's age.
public struct ObservedHighLowWaterLevel: Codable, Hashable, Sendable {
  /// Raw inferred-value and level-limit flags in provider order.
  public let flags: String
  /// Reported finite height in requested metric meters or English feet and requested datum.
  public let height: TidesNumericValue
  /// The unchanged event code, including provider padding and unfamiliar codes.
  public let kind: ObservedHighLowWaterLevelKind
  /// Exact observed event time in GMT.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case height = "v"
    case kind = "ty"
    case time = "t"
  }
}
