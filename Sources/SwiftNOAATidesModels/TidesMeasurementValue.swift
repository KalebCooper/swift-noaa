/// A numeric measurement string that preserves the provider's empty missing-value form.
///
/// `try TidesMeasurementValue("")` has no numeric value; `try TidesMeasurementValue("0")`
/// is a measured zero. Other malformed or non-finite text is rejected, never treated as missing.
public struct TidesMeasurementValue: Codable, Hashable, Sendable {
  /// The exact numeric text, or the empty string for a missing value.
  public let rawValue: String
  /// The finite number, or nil only when the provider text is empty.
  public let value: Double?

  /// Validates numeric text or the explicit empty missing-value form.
  /// - Parameter rawValue: A finite JSON decimal string or an empty string.
  /// - Throws: `TidesQueryError.invalidNumber` for any other representation.
  public init(_ rawValue: String) throws(TidesQueryError) {
    self.rawValue = rawValue
    self.value = rawValue.isEmpty ? nil : try TidesNumericValue(rawValue).value
  }

  /// Decodes a string while distinguishing missing data from malformed values.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    do { try self.init(raw) } catch {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected finite numeric text or an empty measurement: \(raw)")
    }
  }

  /// Encodes the original string, including the empty missing-value form.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
