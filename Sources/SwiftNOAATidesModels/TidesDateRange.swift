#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Explicit, increasing GMT minute bounds, both inclusive at the provider.
///
/// Construct with `try TidesDateRange(begin: start, end: finish)`. Bounds are never
/// rounded, split, or based on the current clock. Individual products enforce calendar limits.
public struct TidesDateRange: Hashable, Sendable {
  /// The inclusive beginning of the requested window.
  public let begin: Date
  /// The inclusive end of the requested window.
  public let end: Date

  /// Validates increasing finite dates aligned to exact minutes.
  /// - Parameters:
  ///   - begin: The first requested GMT minute, in years 1 through 9999.
  ///   - end: A later GMT minute, in years 1 through 9999.
  /// - Throws: `TidesQueryError.invalidDateRange` or `TidesQueryError.nonMinuteAlignedDate`.
  public init(begin: Date, end: Date) throws(TidesQueryError) {
    guard begin < end, TidesTimestamp.text(for: begin) != nil, TidesTimestamp.text(for: end) != nil
    else { throw .invalidDateRange }
    guard
      [begin, end].allSatisfy({ $0.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) == 0 })
    else { throw .nonMinuteAlignedDate }
    self.begin = begin
    self.end = end
  }

  func validate(maximumMonths: Int) throws(TidesQueryError) {
    guard
      let limit = TidesTimestamp.calendar.date(byAdding: .month, value: maximumMonths, to: begin),
      end <= limit
    else { throw .rangeTooLong(maximumMonths: maximumMonths) }
  }

  static func encoded(_ date: Date) -> String {
    guard let text = TidesTimestamp.text(for: date) else {
      preconditionFailure("A validated date range has representable GMT bounds.")
    }
    return String(text.filter { $0 != "-" })
  }
}
