/// An extensible MADIS quality-control code.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
public struct QualityControlCode: Codable, Hashable, RawRepresentable, Sendable {
  /// A coarse pass through level 1 quality control.
  public static let coarsePass = Self(rawValue: "C")

  /// Preliminary data with no quality control available.
  public static let preliminary = Self(rawValue: "Z")

  /// A questioned value that passed level 1 and failed level 2 or 3.
  public static let questioned = Self(rawValue: "Q")

  /// A rejected or erroneous value that failed level 1.
  public static let rejected = Self(rawValue: "X")

  /// A screened value that passed levels 1 and 2.
  public static let screened = Self(rawValue: "S")

  /// A value marked bad by subjective intervention.
  public static let subjectiveBad = Self(rawValue: "B")

  /// A value marked good by subjective intervention.
  public static let subjectiveGood = Self(rawValue: "G")

  /// A verified value that passed levels 1, 2, and 3.
  public static let verified = Self(rawValue: "V")

  /// An air temperature returned because virtual temperature could not be calculated.
  public static let virtualTemperatureUnavailable = Self(rawValue: "T")

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  /// - Parameter value: The value whose raw string to retain.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code without restricting future service values.
  /// - Parameter rawValue: The exact code.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact service code.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a non-string value.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact service code.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
