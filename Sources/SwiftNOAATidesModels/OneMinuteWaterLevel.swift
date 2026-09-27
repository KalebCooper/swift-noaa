/// A preliminary one-minute water level, preserving only fields reported by this product.
/// Missing measurements and omitted minutes remain gaps, without resampling or inferred quality fields.
public struct OneMinuteWaterLevel: Codable, Hashable, Sendable {
  /// Height in requested metric meters or English feet and the requested datum; empty text is missing.
  public let height: TidesMeasurementValue
  /// Exact observation time in GMT.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case height = "v"
    case time = "t"
  }
}
