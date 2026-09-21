#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The metadata for a forecast office's current weather briefing, as `/offices/{officeId}/briefing`
/// describes it.
///
/// Every field is optional because the route documents none of them as required: a missing or
/// `null` field decodes as nil. A value that is present but malformed, such as a date that is not
/// ISO 8601 or a priority that is not a Boolean, fails to decode. Identifiers are kept as the
/// service sends them and are not validated as UUIDs. Dates decode as ISO 8601 independently of the
/// decoder's date strategy.
///
/// ``download`` is the API link to the briefing's document. This package never requests it and
/// does not retrieve briefing documents.
///
/// ```swift
/// if let briefing = try await weather.officeBriefing(officeIdentifier: "LWX") {
///   print(briefing.description ?? "")  // "NWS Baltimore/Washington 7-day Hazardous Weather Briefing"
/// }
/// ```
public struct OfficeBriefing: Codable, Hashable, Sendable {
  /// The office's description of the briefing, such as
  /// `NWS Baltimore/Washington 7-day Hazardous Weather Briefing`.
  public var description: String?

  /// The API link to the briefing's document, which the SDK never requests.
  public var download: URL?

  /// When the briefing stops being current.
  public var endTime: Date?

  /// The briefing's identifier, kept exactly as the service sends it.
  public var id: String?

  /// The identifier of the office that published the briefing, such as `LWX`.
  public var officeId: String?

  /// Whether the office marked the briefing a priority, or nil when the service reports nothing.
  public var priority: Bool?

  /// When the briefing becomes current.
  public var startTime: Date?

  /// The briefing's title, such as `Click to view briefing`.
  public var title: String?

  /// When the office last updated the briefing.
  public var updateTime: Date?

  /// Creates briefing metadata.
  ///
  /// - Parameters:
  ///   - description: The office's description of the briefing.
  ///   - download: The API link to the briefing's document.
  ///   - endTime: When the briefing stops being current.
  ///   - id: The briefing's identifier.
  ///   - officeId: The identifier of the office that published the briefing.
  ///   - priority: Whether the office marked the briefing a priority.
  ///   - startTime: When the briefing becomes current.
  ///   - title: The briefing's title.
  ///   - updateTime: When the office last updated the briefing.
  public init(
    description: String? = nil,
    download: URL? = nil,
    endTime: Date? = nil,
    id: String? = nil,
    officeId: String? = nil,
    priority: Bool? = nil,
    startTime: Date? = nil,
    title: String? = nil,
    updateTime: Date? = nil
  ) {
    self.description = description
    self.download = download
    self.endTime = endTime
    self.id = id
    self.officeId = officeId
    self.priority = priority
    self.startTime = startTime
    self.title = title
    self.updateTime = updateTime
  }

  /// Decodes briefing metadata, reading its dates as ISO 8601 text.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a present field of the wrong type, a date that is not ISO 8601,
  ///   or a download link that is not a URL.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      description: try container.decodeIfPresent(String.self, forKey: .description),
      download: try container.decodeIfPresent(URL.self, forKey: .download),
      endTime: try container.decodeISO8601IfPresent(forKey: .endTime),
      id: try container.decodeIfPresent(String.self, forKey: .id),
      officeId: try container.decodeIfPresent(String.self, forKey: .officeId),
      priority: try container.decodeIfPresent(Bool.self, forKey: .priority),
      startTime: try container.decodeISO8601IfPresent(forKey: .startTime),
      title: try container.decodeIfPresent(String.self, forKey: .title),
      updateTime: try container.decodeISO8601IfPresent(forKey: .updateTime)
    )
  }

  /// Encodes the briefing metadata, writing its dates as ISO 8601 text.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(download, forKey: .download)
    try container.encodeIfPresent(endTime?.formatted(style), forKey: .endTime)
    try container.encodeIfPresent(id, forKey: .id)
    try container.encodeIfPresent(officeId, forKey: .officeId)
    try container.encodeIfPresent(priority, forKey: .priority)
    try container.encodeIfPresent(startTime?.formatted(style), forKey: .startTime)
    try container.encodeIfPresent(title, forKey: .title)
    try container.encodeIfPresent(updateTime?.formatted(style), forKey: .updateTime)
  }

  private enum CodingKeys: String, CodingKey {
    case description
    case download
    case endTime
    case id
    case officeId
    case priority
    case startTime
    case title
    case updateTime
  }
}
