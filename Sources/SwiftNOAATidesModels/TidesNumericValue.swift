#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A finite number encoded by NOAA as a string, retaining its exact spelling.
///
/// For example, `try TidesNumericValue("-0.010")` retains the trailing zero.
/// The parser accepts JSON decimal syntax, including exponents, without whitespace.
/// Empty strings, non-finite numbers, and malformed present values are rejected.
public struct TidesNumericValue: Codable, Hashable, Sendable {
  /// The unchanged provider text.
  public let rawValue: String
  /// The finite numeric interpretation, without unit or datum conversion.
  public let value: Double

  /// Validates numeric text without trimming or rounding it.
  /// - Parameter rawValue: A finite JSON decimal number encoded as text.
  /// - Throws: `TidesQueryError.invalidNumber` for invalid or non-finite text.
  public init(_ rawValue: String) throws(TidesQueryError) {
    guard !rawValue.isEmpty,
      rawValue.utf8.allSatisfy({ "0123456789.eE+-".utf8.contains($0) }),
      let value = try? JSONDecoder().decode(Double.self, from: Data(rawValue.utf8)), value.isFinite
    else { throw .invalidNumber(rawValue) }
    self.rawValue = rawValue
    self.value = value
  }

  /// Decodes strict numeric text, independently of date and nonconforming-float strategies.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    do { try self.init(raw) } catch {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Expected finite numeric text: \(raw)")
    }
  }

  /// Encodes the original provider string.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
