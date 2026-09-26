/// A reported sample of predicted tide height, without an inferred event kind.
public struct TidePrediction: Codable, Hashable, Sendable {
  /// Height in the requested units and datum, retaining numeric text.
  public let height: TidesNumericValue
  /// The sample's GMT minute.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case height = "v"
    case time = "t"
  }
}
