/// A JSON value in an open-ended alert parameter.
/// Numbers are represented as Swift Double values.
///
/// ```swift
/// let parameter = JSONValue.string("NPWEWX")
/// ```
public enum JSONValue: Codable, Hashable, Sendable {
  /// An ordered array.
  case array([JSONValue])
  /// A Boolean value.
  case bool(Bool)
  /// A JSON null.
  case null
  /// A floating-point number.
  case number(Double)
  /// An object with open keys.
  case object([String: JSONValue])
  /// A string.
  case string(String)

  /// Decodes a JSON value without discarding unknown parameter shapes.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for an unsupported value.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSONValue].self))
    }
  }

  /// Encodes the retained JSON shape.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .array(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .number(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    }
  }
}
