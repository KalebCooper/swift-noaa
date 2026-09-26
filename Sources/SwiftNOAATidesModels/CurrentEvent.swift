/// One predicted current max/slack event, distinct from measured currents.
public struct CurrentEvent: Codable, Hashable, Sendable {
  /// Reported bin text, without inferring a deployment or depth.
  public let bin: String
  /// Reported depth in response units, or explicit null, retaining numeric text.
  public let depth: TidesNumericValue?
  /// Provider event kind; slack can have a small nonzero signed velocity.
  public let kind: CurrentEventKind
  /// Mean ebb direction in degrees.
  public let meanEbbDirection: Double
  /// Mean flood direction in degrees.
  public let meanFloodDirection: Double
  /// Reported GMT minute.
  public let time: TidesTimestamp
  /// Signed major-axis velocity in response units; never normalized to zero.
  public let velocityMajor: Double

  private enum CodingKeys: String, CodingKey {
    case bin = "Bin"
    case depth = "Depth"
    case kind = "Type"
    case meanEbbDirection = "meanEbbDir"
    case meanFloodDirection = "meanFloodDir"
    case time = "Time"
    case velocityMajor = "Velocity_Major"
  }

  /// Decodes a complete record, preserving an explicitly null depth.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    bin = try c.decode(String.self, forKey: .bin)
    depth = try c.decode(TidesNumericValue?.self, forKey: .depth)
    kind = try c.decode(CurrentEventKind.self, forKey: .kind)
    meanEbbDirection = try c.decode(Double.self, forKey: .meanEbbDirection)
    meanFloodDirection = try c.decode(Double.self, forKey: .meanFloodDirection)
    time = try c.decode(TidesTimestamp.self, forKey: .time)
    velocityMajor = try c.decode(Double.self, forKey: .velocityMajor)
    guard meanEbbDirection.isFinite, meanFloodDirection.isFinite, velocityMajor.isFinite else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Non-finite event velocity or direction."))
    }
  }

  /// Encodes the original fields without unit conversion.
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(bin, forKey: .bin)
    try c.encode(depth, forKey: .depth)
    try c.encode(kind, forKey: .kind)
    try c.encode(meanEbbDirection, forKey: .meanEbbDirection)
    try c.encode(meanFloodDirection, forKey: .meanFloodDirection)
    try c.encode(time, forKey: .time)
    try c.encode(velocityMajor, forKey: .velocityMajor)
  }
}
