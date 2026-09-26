/// A requested sampled-current velocity representation, separate from the returned representation.
///
/// NOAA may return major-axis data even when speed/direction was requested. Inspect each
/// `CurrentPrediction.velocity` instead of inferring its representation from this query option.
public enum CurrentPredictionMode: String, CaseIterable, Hashable, Sendable {
  /// Requests signed major-axis velocity with mean ebb/flood directions.
  case major = "default"
  /// Requests two-dimensional speed and direction, only for sampled predictions.
  case speedAndDirection = "speed_dir"
}
