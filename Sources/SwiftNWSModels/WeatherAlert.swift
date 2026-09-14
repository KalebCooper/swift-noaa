#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A CAP alert returned by the National Weather Service.
///
/// Dates decode as ISO 8601 independently of the decoder's date strategy.
///
/// ```swift
/// let alert = try JSONDecoder().decode(Feature<WeatherAlert>.self, from: body).properties
/// ```
public struct WeatherAlert: Codable, Hashable, Sendable {
  /// The links to affected zones.
  public var affectedZones: [URL]

  /// The affected area description.
  public var areaDesc: String

  /// The CAP category code, including unknown values.
  public var category: AlertCategory

  /// The certainty of the event.
  public var certainty: AlertCertainty

  /// The special handling code.
  public var code: String?

  /// The full event description.
  public var description: String

  /// When the alert takes effect.
  public var effective: Date

  /// The expected event end, when known.
  public var ends: Date?

  /// The event name.
  public var event: String

  /// The event codes with open keys and values.
  public var eventCode: [String: [JSONValue]]?

  /// When the alert information expires.
  public var expires: Date

  /// The affected-area geocodes, including unknown code systems.
  public var geocode: [String: [String]]?

  /// The headline, when reported.
  public var headline: String?

  /// The service's alert identifier.
  public var id: String

  /// The recommended action, when reported.
  public var instruction: String?

  /// The language code.
  public var language: String?

  /// The alert message type.
  public var messageType: AlertMessageType

  /// The additional note, when reported.
  public var note: String?

  /// The expected event onset, when known.
  public var onset: Date?

  /// The open-ended CAP parameters.
  public var parameters: [String: [JSONValue]]?

  /// The prior alerts updated or replaced.
  public var references: [AlertReference]?

  /// The CAP response code, including unknown values.
  public var response: AlertResponse

  /// The distribution scope.
  public var scope: AlertScope?

  /// The sender identifier.
  public var sender: String

  /// The originator's name.
  public var senderName: String

  /// When the alert was sent.
  public var sent: Date

  /// The severity of the event.
  public var severity: AlertSeverity

  /// The CAP status.
  public var status: AlertStatus

  /// The urgency of the event.
  public var urgency: AlertUrgency

  /// The provider's additional-information link, retained verbatim.
  public var web: String?

  /// Creates an alert from service values.
  ///
  /// - Parameters:
  ///   - affectedZones: The links to affected zones.
  ///   - areaDesc: The affected area description.
  ///   - category: The CAP category code, including unknown values.
  ///   - certainty: The certainty of the event.
  ///   - code: The special handling code.
  ///   - description: The full event description.
  ///   - effective: When the alert takes effect.
  ///   - ends: The expected event end, when known.
  ///   - event: The event name.
  ///   - eventCode: The event codes with open keys and values.
  ///   - expires: When the alert information expires.
  ///   - geocode: The affected-area geocodes, including unknown code systems.
  ///   - headline: The headline, when reported.
  ///   - id: The service's alert identifier.
  ///   - instruction: The recommended action, when reported.
  ///   - language: The language code.
  ///   - messageType: The alert message type.
  ///   - note: The additional note, when reported.
  ///   - onset: The expected event onset, when known.
  ///   - parameters: The open-ended CAP parameters.
  ///   - references: The prior alerts updated or replaced.
  ///   - response: The CAP response code, including unknown values.
  ///   - scope: The distribution scope.
  ///   - sender: The sender identifier.
  ///   - senderName: The originator's name.
  ///   - sent: When the alert was sent.
  ///   - severity: The severity of the event.
  ///   - status: The CAP status.
  ///   - urgency: The urgency of the event.
  ///   - web: The provider's additional-information link, retained verbatim.
  public init(
    affectedZones: [URL],
    areaDesc: String,
    category: AlertCategory,
    certainty: AlertCertainty,
    code: String? = nil,
    description: String,
    effective: Date,
    ends: Date? = nil,
    event: String,
    eventCode: [String: [JSONValue]]? = nil,
    expires: Date,
    geocode: [String: [String]]? = nil,
    headline: String? = nil,
    id: String,
    instruction: String? = nil,
    language: String? = nil,
    messageType: AlertMessageType,
    note: String? = nil,
    onset: Date? = nil,
    parameters: [String: [JSONValue]]? = nil,
    references: [AlertReference]? = nil,
    response: AlertResponse,
    scope: AlertScope? = nil,
    sender: String,
    senderName: String,
    sent: Date,
    severity: AlertSeverity,
    status: AlertStatus,
    urgency: AlertUrgency,
    web: String? = nil
  ) {
    self.affectedZones = affectedZones
    self.areaDesc = areaDesc
    self.category = category
    self.certainty = certainty
    self.code = code
    self.description = description
    self.effective = effective
    self.ends = ends
    self.event = event
    self.eventCode = eventCode
    self.expires = expires
    self.geocode = geocode
    self.headline = headline
    self.id = id
    self.instruction = instruction
    self.language = language
    self.messageType = messageType
    self.note = note
    self.onset = onset
    self.parameters = parameters
    self.references = references
    self.response = response
    self.scope = scope
    self.sender = sender
    self.senderName = senderName
    self.sent = sent
    self.severity = severity
    self.status = status
    self.urgency = urgency
    self.web = web
  }

  /// Decodes service values, including ISO 8601 dates.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for missing or malformed required values.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      affectedZones: try container.decode([URL].self, forKey: .affectedZones),
      areaDesc: try container.decode(String.self, forKey: .areaDesc),
      category: try container.decode(AlertCategory.self, forKey: .category),
      certainty: try container.decode(AlertCertainty.self, forKey: .certainty),
      code: try container.decodeIfPresent(String.self, forKey: .code),
      description: try container.decode(String.self, forKey: .description),
      effective: try container.decodeISO8601(forKey: .effective),
      ends: try container.decodeISO8601IfPresent(forKey: .ends),
      event: try container.decode(String.self, forKey: .event),
      eventCode: try container.decodeIfPresent([String: [JSONValue]].self, forKey: .eventCode),
      expires: try container.decodeISO8601(forKey: .expires),
      geocode: try container.decodeIfPresent([String: [String]].self, forKey: .geocode),
      headline: try container.decodeIfPresent(String.self, forKey: .headline),
      id: try container.decode(String.self, forKey: .id),
      instruction: try container.decodeIfPresent(String.self, forKey: .instruction),
      language: try container.decodeIfPresent(String.self, forKey: .language),
      messageType: try container.decode(AlertMessageType.self, forKey: .messageType),
      note: try container.decodeIfPresent(String.self, forKey: .note),
      onset: try container.decodeISO8601IfPresent(forKey: .onset),
      parameters: try container.decodeIfPresent([String: [JSONValue]].self, forKey: .parameters),
      references: try container.decodeIfPresent([AlertReference].self, forKey: .references),
      response: try container.decode(AlertResponse.self, forKey: .response),
      scope: try container.decodeIfPresent(AlertScope.self, forKey: .scope),
      sender: try container.decode(String.self, forKey: .sender),
      senderName: try container.decode(String.self, forKey: .senderName),
      sent: try container.decodeISO8601(forKey: .sent),
      severity: try container.decode(AlertSeverity.self, forKey: .severity),
      status: try container.decode(AlertStatus.self, forKey: .status),
      urgency: try container.decode(AlertUrgency.self, forKey: .urgency),
      web: try container.decodeIfPresent(String.self, forKey: .web)
    )
  }

  /// Encodes service values with ISO 8601 dates.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(affectedZones, forKey: .affectedZones)
    try container.encode(areaDesc, forKey: .areaDesc)
    try container.encode(category, forKey: .category)
    try container.encode(certainty, forKey: .certainty)
    try container.encodeIfPresent(code, forKey: .code)
    try container.encode(description, forKey: .description)
    try container.encode(
      effective.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .effective)
    try container.encodeIfPresent(
      ends?.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)), forKey: .ends)
    try container.encode(event, forKey: .event)
    try container.encodeIfPresent(eventCode, forKey: .eventCode)
    try container.encode(
      expires.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)), forKey: .expires
    )
    try container.encodeIfPresent(geocode, forKey: .geocode)
    try container.encodeIfPresent(headline, forKey: .headline)
    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(instruction, forKey: .instruction)
    try container.encodeIfPresent(language, forKey: .language)
    try container.encode(messageType, forKey: .messageType)
    try container.encodeIfPresent(note, forKey: .note)
    try container.encodeIfPresent(
      onset?.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)), forKey: .onset)
    try container.encodeIfPresent(parameters, forKey: .parameters)
    try container.encodeIfPresent(references, forKey: .references)
    try container.encode(response, forKey: .response)
    try container.encodeIfPresent(scope, forKey: .scope)
    try container.encode(sender, forKey: .sender)
    try container.encode(senderName, forKey: .senderName)
    try container.encode(
      sent.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)), forKey: .sent)
    try container.encode(severity, forKey: .severity)
    try container.encode(status, forKey: .status)
    try container.encode(urgency, forKey: .urgency)
    try container.encodeIfPresent(web, forKey: .web)
  }

  private enum CodingKeys: String, CodingKey {
    case affectedZones
    case areaDesc
    case category
    case certainty
    case code
    case description
    case effective
    case ends
    case event
    case eventCode
    case expires
    case geocode
    case headline
    case id
    case instruction
    case language
    case messageType
    case note
    case onset
    case parameters
    case references
    case response
    case scope
    case sender
    case senderName
    case sent
    case severity
    case status
    case urgency
    case web
  }
}
