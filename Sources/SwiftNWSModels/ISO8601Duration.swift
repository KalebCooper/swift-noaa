/// An ISO 8601 duration as the service writes it, such as `PT3H` or `P1DT19H`.
///
/// The components keep the text's own units: `P1DT19H` has one day and nineteen hours, never
/// forty-three hours. The accepted grammar is exactly the service's: `P`, then optional years,
/// months, and days in that order, then optionally `T` followed by at least one of hours, minutes,
/// and seconds in that order, with at least one component overall. Each component is a run of ASCII
/// digits. Weeks, fractions, signs, lowercase designators, whitespace, and out-of-order components
/// are rejected.
///
/// ```swift
/// let duration = ISO8601Duration(rawValue: "P1DT19H")
/// print(duration?.days, duration?.hours)  // Optional(1) Optional(19)
/// print(duration?.exactDuration)          // Optional(154800.0 seconds)
/// ```
///
/// Equality compares the text: `PT1H` and `PT60M` are different durations.
public struct ISO8601Duration: Codable, Hashable, RawRepresentable, Sendable {
  /// The number of days.
  public let days: Int

  /// The number of hours.
  public let hours: Int

  /// The number of minutes.
  public let minutes: Int

  /// The number of months, which have no fixed length.
  public let months: Int

  /// The exact text the duration was parsed from.
  public let rawValue: String

  /// The number of seconds.
  public let seconds: Int

  /// The number of years, which have no fixed length.
  public let years: Int

  /// The duration's length, counting a day as 86,400 seconds.
  ///
  /// `nil` when the duration has years or months, which have no fixed length, or when the length
  /// does not fit in a 64-bit count of seconds. A day is exactly 86,400 seconds here because the
  /// service writes each interval's start with a fixed UTC offset, so no daylight-saving change
  /// applies to the arithmetic.
  public var exactDuration: Duration? {
    guard years == 0, months == 0 else { return nil }
    let parts: [(count: Int, unit: Int64)] = [
      (days, 86_400), (hours, 3_600), (minutes, 60), (seconds, 1),
    ]
    var total: Int64 = 0
    for (count, unit) in parts {
      let (scaled, multiplyOverflow) = Int64(count).multipliedReportingOverflow(by: unit)
      guard !multiplyOverflow else { return nil }
      let (sum, addOverflow) = total.addingReportingOverflow(scaled)
      guard !addOverflow else { return nil }
      total = sum
    }
    return .seconds(total)
  }

  /// Parses an ISO 8601 duration.
  ///
  /// Returns `nil` for text outside the service's grammar, such as `P`, `PT`, `P1DT`, `P1W`,
  /// `PT1.5H`, `-PT1H`, `pt1h`, `P1M1Y`, or a component too large for `Int`. `P0D` and `PT0S` are
  /// accepted.
  ///
  /// - Parameter rawValue: The duration's text.
  public init?(rawValue: String) {
    // Values in designator order: years, months, days, then hours, minutes, seconds.
    let designators = Array("YMDHMS".utf8)
    var values = [Int?](repeating: nil, count: designators.count)
    var bytes = rawValue.utf8.makeIterator()
    guard bytes.next() == UInt8(ascii: "P") else { return nil }
    // The next position a designator may occupy, and the end of the current part.
    var next = 0
    var end = 3
    var number: Int?
    while let byte = bytes.next() {
      if byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
        let (scaled, multiplyOverflow) = (number ?? 0).multipliedReportingOverflow(by: 10)
        let (sum, addOverflow) = scaled.addingReportingOverflow(Int(byte - UInt8(ascii: "0")))
        guard !multiplyOverflow, !addOverflow else { return nil }
        number = sum
      } else if byte == UInt8(ascii: "T") {
        guard end == 3, number == nil else { return nil }
        next = 3
        end = 6
      } else {
        guard let value = number,
          let position = designators[next..<end].firstIndex(of: byte)
        else { return nil }
        values[position] = value
        next = position + 1
        number = nil
      }
    }
    let hasDate = values[0..<3].contains { $0 != nil }
    let hasTime = values[3..<6].contains { $0 != nil }
    // A `T` must introduce at least one time component.
    guard number == nil, hasDate || hasTime, end == 3 || hasTime else { return nil }
    self.days = values[2] ?? 0
    self.hours = values[3] ?? 0
    self.minutes = values[4] ?? 0
    self.months = values[1] ?? 0
    self.rawValue = rawValue
    self.seconds = values[5] ?? 0
    self.years = values[0] ?? 0
  }

  /// Decodes a duration from its text.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError.dataCorrupted` naming the text when it is not an ISO 8601 duration
  ///   in the service's grammar.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    guard let duration = Self(rawValue: text) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Expected an ISO 8601 duration, found \"\(text)\".")
    }
    self = duration
  }

  /// Encodes the duration's exact text.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
