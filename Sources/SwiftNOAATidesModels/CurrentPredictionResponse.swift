/// An independently decodable sampled-current prediction envelope.
///
/// Retains provider-reported units separately from any requested unit system.
public struct CurrentPredictionResponse: Codable, Hashable, Sendable {
  /// Reported predictions in provider order.
  public let predictions: [CurrentPrediction]
  /// Provider-reported depth and velocity units, preserved as exact text.
  public let units: String

  private enum CodingKeys: String, CodingKey { case predictions = "current_predictions" }

  private struct Payload: Codable {
    let cp: [CurrentPrediction]
    let units: String
  }

  /// Decodes the required nested units and array without request context.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let p = try c.decode(Payload.self, forKey: .predictions)
    predictions = p.cp
    units = p.units
  }

  /// Encodes the nested provider envelope.
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(Payload(cp: predictions, units: units), forKey: .predictions)
  }
}
