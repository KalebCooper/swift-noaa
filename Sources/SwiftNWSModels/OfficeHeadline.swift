#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One editorial headline a forecast office publishes, as `/offices/{officeId}/headlines/{headlineId}`
/// describes it and `/offices/{officeId}/headlines` lists it.
///
/// The identifier and title are always present. Every other field is optional because the service
/// nulls or omits some of them: a recorded headline sends a `null` summary. Text is kept exactly as
/// sent, including the HTML markup and percent escapes in ``content``; this package does not render,
/// escape, or strip it. ``link`` is editorial content that can point outside the API origin, so it
/// is kept as text and is not an endpoint to follow. Dates decode as ISO 8601 independently of the decoder's date
/// strategy.
///
/// ```swift
/// let headline = try await weather.officeHeadline(
///   identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")
/// print(headline.title)  // "Update on ENSO and Impacts on South-Central Texas"
/// ```
public struct OfficeHeadline: Codable, Hashable, Sendable {
  /// The headline's body, with its HTML markup and percent escapes unchanged.
  public var content: String?

  /// The headline's identifier, such as `ab45482ca5f57ff412eb1320721d5ac9`.
  public var id: String

  /// Whether the office marked the headline important, or nil when the service reports nothing.
  public var important: Bool?

  /// When the office issued the headline.
  public var issuanceTime: Date?

  /// The editorial link the headline points at, kept exactly as the service sends it.
  ///
  /// This is content for a reader, not a detail endpoint: it can be outside the API origin, and the
  /// SDK never sends a request to it. It is text rather than a `URL` so that an empty or malformed
  /// value is preserved and never fails the headline, or the list around it, to decode.
  public var link: String?

  /// The office's short name for the headline, such as `ensostorymap`.
  public var name: String?

  /// A link to the office that published the headline.
  public var office: URL?

  /// The headline's summary, which the service sends as `null` for some headlines.
  public var summary: String?

  /// The headline's title, such as `Update on ENSO and Impacts on South-Central Texas`.
  public var title: String

  /// The headline's own API identity URL, from the response's `@id`.
  public var url: URL?

  /// Creates a headline.
  ///
  /// - Parameters:
  ///   - content: The headline's body.
  ///   - id: The headline's identifier.
  ///   - important: Whether the office marked the headline important.
  ///   - issuanceTime: When the office issued the headline.
  ///   - link: The editorial link the headline points at.
  ///   - name: The office's short name for the headline.
  ///   - office: A link to the office that published the headline.
  ///   - summary: The headline's summary.
  ///   - title: The headline's title.
  ///   - url: The headline's own API identity URL.
  public init(
    content: String? = nil,
    id: String,
    important: Bool? = nil,
    issuanceTime: Date? = nil,
    link: String? = nil,
    name: String? = nil,
    office: URL? = nil,
    summary: String? = nil,
    title: String,
    url: URL? = nil
  ) {
    self.content = content
    self.id = id
    self.important = important
    self.issuanceTime = issuanceTime
    self.link = link
    self.name = name
    self.office = office
    self.summary = summary
    self.title = title
    self.url = url
  }

  /// Decodes a headline, reading its issuance time as ISO 8601 text.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a missing identifier or title, or an issuance time that is not
  ///   ISO 8601.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      content: try container.decodeIfPresent(String.self, forKey: .content),
      id: try container.decode(String.self, forKey: .id),
      important: try container.decodeIfPresent(Bool.self, forKey: .important),
      issuanceTime: try container.decodeISO8601IfPresent(forKey: .issuanceTime),
      link: try container.decodeIfPresent(String.self, forKey: .link),
      name: try container.decodeIfPresent(String.self, forKey: .name),
      office: try container.decodeIfPresent(URL.self, forKey: .office),
      summary: try container.decodeIfPresent(String.self, forKey: .summary),
      title: try container.decode(String.self, forKey: .title),
      url: try container.decodeIfPresent(URL.self, forKey: .url)
    )
  }

  /// Encodes the headline, writing its issuance time as ISO 8601 text.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(content, forKey: .content)
    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(important, forKey: .important)
    try container.encodeIfPresent(
      issuanceTime?.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .issuanceTime)
    try container.encodeIfPresent(link, forKey: .link)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encodeIfPresent(office, forKey: .office)
    try container.encodeIfPresent(summary, forKey: .summary)
    try container.encode(title, forKey: .title)
    try container.encodeIfPresent(url, forKey: .url)
  }

  private enum CodingKeys: String, CodingKey {
    case content
    case id
    case important
    case issuanceTime
    case link
    case name
    case office
    case summary
    case title
    case url = "@id"
  }
}
