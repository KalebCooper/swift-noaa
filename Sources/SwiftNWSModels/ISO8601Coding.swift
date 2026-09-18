#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Parses an ISO 8601 date-time as the service writes it, with or without fractional seconds.
///
/// Every date the package decodes goes through this function, so date acceptance is identical in
/// every model.
func parseISO8601(_ text: String) -> Date? {
  (try? Date(text, strategy: .iso8601))
    ?? (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
}

extension KeyedDecodingContainer {
  func decodeISO8601(forKey key: Key) throws -> Date {
    let text = try decode(String.self, forKey: key)
    guard let date = parseISO8601(text) else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: self, debugDescription: "Expected an ISO 8601 date.")
    }
    return date
  }
  func decodeISO8601IfPresent(forKey key: Key) throws -> Date? {
    guard contains(key), try !decodeNil(forKey: key) else { return nil }
    return try decodeISO8601(forKey: key)
  }
}
