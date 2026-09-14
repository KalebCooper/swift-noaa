#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension KeyedDecodingContainer {
  func decodeISO8601(forKey key: Key) throws -> Date {
    let text = try decode(String.self, forKey: key)
    guard
      let date = (try? Date(text, strategy: .iso8601))
        ?? (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    else {
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
