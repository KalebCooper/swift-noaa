/// One predicted high or low tide, without inferred station, datum, or units.
public struct HighLowTide: Codable, Hashable, Sendable {
  /// The signed predicted height, retaining its exact numeric text.
  public let height: TidesNumericValue
  /// The provider's event kind, including unknown codes.
  public let kind: TideEventKind
  /// The event's GMT time; no local-time interpretation is performed.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case height = "v"
    case kind = "type"
    case time = "t"
  }
}
