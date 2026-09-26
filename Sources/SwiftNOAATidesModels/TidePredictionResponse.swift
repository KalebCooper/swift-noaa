/// An independently decodable sampled tide envelope; station, units, and datum are not echoed.
public struct TidePredictionResponse: Codable, Hashable, Sendable {
  /// Reported samples in provider order, without interpolation or inferred extrema.
  public let predictions: [TidePrediction]
}
