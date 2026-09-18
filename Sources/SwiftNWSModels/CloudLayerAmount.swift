/// An extensible METAR sky coverage code for a cloud layer.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if layer.amount == .overcast {
///   print("Ceiling at \(layer.base.value ?? .nan) \(layer.base.unitCode)")
/// }
/// ```
public struct CloudLayerAmount: Codable, Hashable, RawRepresentable, Sendable {
  /// Five to seven eighths of the sky covered, `BKN`.
  public static let broken = Self(rawValue: "BKN")

  /// No cloud detected below the automated sensor's limit, `CLR`.
  public static let clear = Self(rawValue: "CLR")

  /// One to two eighths of the sky covered, `FEW`.
  public static let few = Self(rawValue: "FEW")

  /// The whole sky covered, `OVC`.
  public static let overcast = Self(rawValue: "OVC")

  /// Three to four eighths of the sky covered, `SCT`.
  public static let scattered = Self(rawValue: "SCT")

  /// No cloud, as a human observer reports it, `SKC`.
  public static let skyClear = Self(rawValue: "SKC")

  /// The sky hidden by a surface-based obscuration, with the layer's base as the vertical
  /// visibility, `VV`.
  public static let verticalVisibility = Self(rawValue: "VV")

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
