#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A strict minute-resolution timestamp from a response requested in GMT.
///
/// Use `try TidesTimestamp("2024-02-29 12:30")`. This type must not be used to
/// interpret station-local text; built-in data endpoints always request `time_zone=gmt`.
public struct TidesTimestamp: Codable, Hashable, Sendable {
  /// The corresponding instant in GMT.
  public let date: Date
  /// The exact provider text in yyyy-MM-dd HH:mm form.
  public let rawValue: String

  /// Parses an exact Gregorian GMT minute without normalization.
  /// - Parameter rawValue: A timestamp with no offset or seconds.
  /// - Throws: `TidesQueryError.invalidTimestamp` for invalid dates, times, or spelling.
  public init(_ rawValue: String) throws(TidesQueryError) {
    let bytes = Array(rawValue.utf8)
    guard bytes.count == 16, bytes[4] == 45, bytes[7] == 45, bytes[10] == 32, bytes[13] == 58,
      bytes.enumerated().allSatisfy({
        [4, 7, 10, 13].contains($0.offset) || (48...57).contains($0.element)
      }),
      let year = Int(String(decoding: bytes[0..<4], as: UTF8.self)), year > 0,
      let month = Int(String(decoding: bytes[5..<7], as: UTF8.self)),
      let day = Int(String(decoding: bytes[8..<10], as: UTF8.self)),
      let hour = Int(String(decoding: bytes[11..<13], as: UTF8.self)),
      let minute = Int(String(decoding: bytes[14..<16], as: UTF8.self)),
      let date = Self.calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)),
      Self.text(for: date) == rawValue
    else { throw .invalidTimestamp(rawValue) }
    self.date = date
    self.rawValue = rawValue
  }

  /// Decodes GMT text without consulting JSONDecoder's date strategy.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    do { try self.init(raw) } catch {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Expected an exact GMT minute: \(raw)")
    }
  }

  /// Encodes the original GMT text.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    guard let zone = TimeZone(secondsFromGMT: 0) else {
      preconditionFailure("GMT is a valid fixed-offset time zone.")
    }
    calendar.timeZone = zone
    return calendar
  }

  static func text(for date: Date) -> String? {
    guard date.timeIntervalSince1970.isFinite else { return nil }
    let parts = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute], from: date)
    guard parts.era == 1, let year = parts.year, (1...9999).contains(year),
      let month = parts.month, let day = parts.day, let hour = parts.hour, let minute = parts.minute
    else { return nil }
    func pad(_ value: Int, _ width: Int = 2) -> String {
      let text = String(value)
      return String(repeating: "0", count: max(0, width - text.count)) + text
    }
    return "\(pad(year, 4))-\(pad(month))-\(pad(day)) \(pad(hour)):\(pad(minute))"
  }
}
