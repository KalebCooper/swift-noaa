/// The actual velocity representation in one sampled current prediction.
///
/// Major-axis velocity is signed; speed/direction is two-dimensional. Neither is converted
/// into the other. Requested mode and actual representation can differ.
public enum CurrentVelocity: Codable, Hashable, Sendable {
  /// Signed velocity and mean ebb/flood directions in degrees; velocity units come from the response.
  case major(meanEbbDirection: Double, meanFloodDirection: Double, velocity: Double)
  /// Direction in degrees and raw numeric speed; speed units come from the response.
  case speedAndDirection(direction: Double, speed: TidesNumericValue)

  private enum CodingKeys: String, CodingKey {
    case direction = "Direction"
    case meanEbbDirection = "meanEbbDir"
    case meanFloodDirection = "meanFloodDir"
    case speed = "Speed"
    case velocity = "Velocity_Major"
  }

  /// Decodes one complete provider representation and rejects mixed or incomplete fields.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if c.contains(.velocity) {
      guard !c.contains(.speed), !c.contains(.direction) else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: decoder.codingPath,
            debugDescription: "Mixed current velocity representations."))
      }
      let ebb = try c.decode(Double.self, forKey: .meanEbbDirection)
      let flood = try c.decode(Double.self, forKey: .meanFloodDirection)
      let velocity = try c.decode(Double.self, forKey: .velocity)
      guard ebb.isFinite, flood.isFinite, velocity.isFinite else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: decoder.codingPath,
            debugDescription: "Non-finite current velocity or direction."))
      }
      self = .major(meanEbbDirection: ebb, meanFloodDirection: flood, velocity: velocity)
    } else {
      guard !c.contains(.meanEbbDirection), !c.contains(.meanFloodDirection) else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: decoder.codingPath, debugDescription: "Incomplete major-axis velocity.")
        )
      }
      let direction = try c.decode(Double.self, forKey: .direction)
      guard direction.isFinite else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: decoder.codingPath, debugDescription: "Non-finite current direction."))
      }
      self = .speedAndDirection(
        direction: direction, speed: try c.decode(TidesNumericValue.self, forKey: .speed))
    }
  }

  /// Encodes the original representation using NOAA's field names.
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .major(let ebb, let flood, let velocity):
      try c.encode(ebb, forKey: .meanEbbDirection)
      try c.encode(flood, forKey: .meanFloodDirection)
      try c.encode(velocity, forKey: .velocity)
    case .speedAndDirection(let direction, let speed):
      try c.encode(direction, forKey: .direction)
      try c.encode(speed, forKey: .speed)
    }
  }
}
