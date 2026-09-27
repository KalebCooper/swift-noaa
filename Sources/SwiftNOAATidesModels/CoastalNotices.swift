/// Station notices in provider order, obtained with `notices(stationIdentifier:)`.
public struct CoastalNotices: Codable, Hashable, Sendable {
  /// Required notices; an empty array is a successful response with no notices.
  public let notices: [CoastalNotice]
  /// Resource link text, never followed automatically.
  public let selfLink: String?

  private enum CodingKeys: String, CodingKey {
    case notices
    case selfLink = "self"
  }
}
