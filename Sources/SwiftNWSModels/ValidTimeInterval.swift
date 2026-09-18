#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An ISO 8601 time interval written as a start and a duration, such as
/// `2026-09-17T17:00:00+00:00/PT3H`.
///
/// The service describes when a forecast or a grid value applies with these intervals. Parsing
/// keeps the exact text in ``rawValue``, the start instant, and the duration's calendar components.
///
/// ```swift
/// let interval = ValidTimeInterval(rawValue: "2026-09-17T17:00:00+00:00/PT3H")
/// print(interval?.duration.hours)  // Optional(3)
/// print(interval?.end)             // Optional(2026-09-17 20:00:00 +0000)
/// ```
///
/// The service's schema also allows a start and an end, a duration and an end, and `NOW` in place of
/// either instant. Those forms are not supported: every interval the service has been observed to
/// send is a start and a duration, and the other forms are rejected rather than guessed at.
///
/// Equality compares the text, so `2026-09-17T17:00:00Z/PT1H` and
/// `2026-09-17T17:00:00+00:00/PT1H` are different intervals even though they name the same time.
public struct ValidTimeInterval: Codable, Hashable, RawRepresentable, Sendable {
  /// The interval's length, as its text states it.
  public let duration: ISO8601Duration

  /// The exact text the interval was parsed from.
  public let rawValue: String

  /// The instant the interval starts.
  public let start: Date

  /// The instant the interval ends, or `nil` when its duration has no exact length.
  ///
  /// A duration with years or months has no fixed length, so no calendar is assumed and the end is
  /// `nil`. See ``ISO8601Duration/exactDuration``.
  public var end: Date? {
    guard let length = duration.exactDuration else { return nil }
    return start.addingTimeInterval(TimeInterval(length.components.seconds))
  }

  /// Parses a start-and-duration interval.
  ///
  /// Returns `nil` unless the text is exactly one ISO 8601 date-time, a `/`, and an
  /// ``ISO8601Duration``. A start-and-end interval, a duration-and-end interval, and `NOW` are
  /// rejected.
  ///
  /// - Parameter rawValue: The interval's text.
  public init?(rawValue: String) {
    let parts = rawValue.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2,
      let start = parseISO8601(String(parts[0])),
      let duration = ISO8601Duration(rawValue: String(parts[1]))
    else { return nil }
    self.duration = duration
    self.rawValue = rawValue
    self.start = start
  }

  /// Decodes an interval from its text.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError.dataCorrupted` naming the text when it is not a start-and-duration
  ///   interval.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    guard let interval = Self(rawValue: text) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected an ISO 8601 start and duration interval, found \"\(text)\".")
    }
    self = interval
  }

  /// Encodes the interval's exact text.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
