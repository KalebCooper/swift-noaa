/// A local CO-OPS query or value validation failure, raised before I/O.
public enum TidesQueryError: Error, Hashable, Sendable {
  /// The range is reversed, equal, non-finite, or outside years 1 through 9999.
  case invalidDateRange
  /// The datum code is empty or contains a control character.
  case invalidDatum(String)
  /// Numeric text is not a finite JSON decimal number.
  case invalidNumber(String)
  /// The station identifier contains unsupported path characters or is empty.
  case invalidStationIdentifier(String)
  /// The directory category is empty or contains a control character.
  case invalidStationType(String)
  /// The timestamp is not an exact Gregorian GMT minute in yyyy-MM-dd HH:mm form.
  case invalidTimestamp(String)
  /// The unit code is empty or contains a control character.
  case invalidUnits(String)
  /// A bound contains seconds or a fractional minute; it was not rounded.
  case nonMinuteAlignedDate
  /// The range exceeds the product's maximum number of Gregorian calendar months.
  case rangeTooLong(maximumMonths: Int)
}
