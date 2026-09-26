/// The direct high/low prediction envelope, independently decodable without request context.
public struct HighLowTideResponse: Codable, Hashable, Sendable {
  /// Every event in provider order; an empty array is distinct from a provider refusal.
  public let predictions: [HighLowTide]
}
