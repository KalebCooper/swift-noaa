/// The provider's native six-minute samples or samples selected on the hour.
public enum CoastalObservationInterval: Hashable, Sendable {
  /// Selects the six-minute value on each hour, without averaging.
  case hourly
  /// Requests the native six-minute series without an interval parameter.
  case sixMinutes
}
