#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A prior alert updated or replaced by another alert.
///
/// Dates decode as ISO 8601 independently of the decoder's date strategy.
///
/// ```swift
/// let reference = alert.references?.first
/// ```
public struct AlertReference: Codable, Hashable, Sendable {
  /// The prior alert's API link.
  public var id: URL

  /// The prior alert identifier.
  public var identifier: String

  /// The prior sender.
  public var sender: String

  /// When the prior alert was sent.
  public var sent: Date

  /// Creates an alert reference from service values.
  ///
  /// - Parameters:
  ///   - id: The prior alert's API link.
  ///   - identifier: The prior alert identifier.
  ///   - sender: The prior sender.
  ///   - sent: When the prior alert was sent.
  public init(
    id: URL,
    identifier: String,
    sender: String,
    sent: Date
  ) {
    self.id = id
    self.identifier = identifier
    self.sender = sender
    self.sent = sent
  }

  /// Decodes service values, including ISO 8601 dates.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for missing or malformed required values.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try container.decode(URL.self, forKey: .id),
      identifier: try container.decode(String.self, forKey: .identifier),
      sender: try container.decode(String.self, forKey: .sender),
      sent: try container.decodeISO8601(forKey: .sent)
    )
  }

  /// Encodes service values with ISO 8601 dates.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(identifier, forKey: .identifier)
    try container.encode(sender, forKey: .sender)
    try container.encode(
      sent.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)), forKey: .sent)
  }

  private enum CodingKeys: String, CodingKey {
    case id = "@id"
    case identifier
    case sender
    case sent
  }
}
