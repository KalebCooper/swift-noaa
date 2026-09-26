/// Supported sampled tide cadences, expressed in minutes.
///
/// Use `.hourly` or `.everySixMinutes`. `TidePredictionInterval(rawValue: 7)` is nil;
/// unsupported cadences cannot form a query. High/low events have their own query type.
public enum TidePredictionInterval: Int, CaseIterable, Hashable, Sendable {
  /// One sample every fifteen minutes.
  case everyFifteenMinutes = 15
  /// One sample every five minutes.
  case everyFiveMinutes = 5
  /// One sample each minute.
  case everyMinute = 1
  /// One sample every six minutes.
  case everySixMinutes = 6
  /// One sample every ten minutes.
  case everyTenMinutes = 10
  /// One sample every thirty minutes.
  case everyThirtyMinutes = 30
  /// One sample every sixty minutes.
  case hourly = 60
}
