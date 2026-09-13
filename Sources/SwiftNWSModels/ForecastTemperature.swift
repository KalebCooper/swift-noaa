/// A forecast temperature preserving its JSON representation.
/// Both legacy and quantitative shapes decode without implicit conversion.
///
/// ```swift
/// if case .quantity(let quantity) = period.temperature {
///   print(quantity.unitCode)
/// }
/// ```
public enum ForecastTemperature: Codable, Hashable, Sendable {
  /// The quantity returned when the corresponding feature flag is enabled.
  case quantity(QuantitativeValue)

  /// The legacy numeric temperature; its unit is in the period.
  case value(Double)

  /// Decodes either a legacy value or a quantitative object.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for an unsupported shape or malformed quantity.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let legacy = try? container.decode(Double.self) {
      self = .value(legacy)
    } else {
      self = .quantity(try container.decode(QuantitativeValue.self))
    }
  }

  /// Encodes the retained representation.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .quantity(let value): try container.encode(value)
    case .value(let value): try container.encode(value)
    }
  }
}
