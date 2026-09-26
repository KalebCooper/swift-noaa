/// Supported sampled current cadences, expressed in minutes.
///
/// Use `.hourly` or `.everySixMinutes`. `CurrentPredictionInterval(rawValue: 7)` is nil;
/// unsupported cadences cannot form a query. Max/slack events have their own query type.
public enum CurrentPredictionInterval: Int, CaseIterable, Hashable, Sendable {
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
