/// One predicted current sample, distinct from measured currents.
public struct CurrentPrediction: Codable, Hashable, Sendable {
  /// Reported bin text, without inferring a deployment or depth.
  public let bin: String
  /// Reported depth in response units, or explicit null, retaining numeric text.
  public let depth: TidesNumericValue?
  /// Reported GMT minute.
  public let time: TidesTimestamp
  /// The actual returned representation, independent of the requested mode.
  public let velocity: CurrentVelocity

  private enum CodingKeys: String, CodingKey {
    case bin = "Bin"
    case depth = "Depth"
    case eventKind = "Type"
    case time = "Time"
  }

  /// Decodes a complete record, preserving an explicitly null depth.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    guard !c.contains(.eventKind) else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Expected sampled currents, received an event."))
    }
    bin = try c.decode(String.self, forKey: .bin)
    depth = try c.decode(TidesNumericValue?.self, forKey: .depth)
    time = try c.decode(TidesTimestamp.self, forKey: .time)
    velocity = try CurrentVelocity(from: decoder)
  }

  /// Encodes the original fields without unit conversion.
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(bin, forKey: .bin)
    try c.encode(depth, forKey: .depth)
    try c.encode(time, forKey: .time)
    try velocity.encode(to: encoder)
  }
}
