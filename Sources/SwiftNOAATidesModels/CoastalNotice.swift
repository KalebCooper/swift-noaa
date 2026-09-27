/// A station notice whose text, markup, and whitespace remain unchanged.
public struct CoastalNotice: Codable, Hashable, Sendable {
  /// The provider's notice name.
  public let name: String
  /// Unrendered notice text, including any HTML.
  public let text: String
}
