/// An open sensor status code; unknown values remain uninterpreted.
public struct CoastalSensorStatus: Codable, Hashable, RawRepresentable, Sendable {
  /// The exact provider integer.
  public let rawValue: Int

  /// NOAA's disabled status.
  public static let disabled = Self(rawValue: 0)
  /// NOAA's enabled status; this does not establish observation freshness.
  public static let enabled = Self(rawValue: 1)

  /// Creates a status preserving any provider code.
  /// - Parameter rawValue: The unchanged integer.
  public init(rawValue: Int) { self.rawValue = rawValue }

  /// Decodes the provider integer without restricting its vocabulary.
  public init(from decoder: any Decoder) throws {
    self.init(rawValue: try decoder.singleValueContainer().decode(Int.self))
  }

  /// Encodes the original integer.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
