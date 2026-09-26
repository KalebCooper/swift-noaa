/// A station's datum table and provider-reported reference metadata.
///
/// Obtain with `datums(stationIdentifier:units:)`. Date and time strings are retained because
/// this metadata endpoint does not accept the Data API's GMT parameter. No conversion is performed.
public struct CoastalDatums: Codable, Hashable, Sendable {
  /// One provider disclaimer accompanying the datum table.
  public struct Disclaimer: Codable, Hashable, Sendable {
    /// The provider's disclaimer name.
    public let name: String
    /// The provider's disclaimer text.
    public let text: String
  }

  /// The embedded disclaimer collection, without following its optional resource link.
  public struct Disclaimers: Codable, Hashable, Sendable {
    /// Required disclaimer entries in provider order.
    public let disclaimers: [Disclaimer]
    /// The resource link text, if present.
    public let selfLink: String?

    private enum CodingKeys: String, CodingKey {
      case disclaimers
      case selfLink = "self"
    }
  }

  /// The provider text describing acceptance.
  public let accepted: String?
  /// Provider-described analysis periods, without date interpretation.
  public let analysisPeriods: [String]?
  /// The control station text, including an empty value.
  public let controlStation: String?
  /// Required datum entries in provider order.
  public let datums: [CoastalDatum]
  /// Provider disclaimers accompanying this table.
  public let disclaimers: Disclaimers?
  /// The provider epoch text.
  public let epoch: String?
  /// The reported highest astronomical tide.
  public let highestAstronomicalTide: Double?
  /// The highest astronomical tide date as provider text.
  public let highestAstronomicalTideDate: String?
  /// The highest astronomical tide time with no assumed time zone.
  public let highestAstronomicalTideTime: String?
  /// The reported least astronomical tide.
  public let leastAstronomicalTide: Double?
  /// The least astronomical tide date as provider text.
  public let leastAstronomicalTideDate: String?
  /// The least astronomical tide time with no assumed time zone.
  public let leastAstronomicalTideTime: String?
  /// The highest observed water level reported in the table.
  public let maximum: Double?
  /// The highest observed level date as provider text.
  public let maximumDate: String?
  /// The highest observed level time with no assumed time zone.
  public let maximumTime: String?
  /// The lowest observed water level reported in the table.
  public let minimum: Double?
  /// The lowest observed level date as provider text.
  public let minimumDate: String?
  /// The lowest observed level time with no assumed time zone.
  public let minimumTime: String?
  /// The external NGS link text, including an empty value.
  public let ngsLink: String?
  /// The reported orthometric datum name.
  public let orthometricDatum: String?
  /// The provider resource link text, without an automatic fetch.
  public let selfLink: String?
  /// The provider supersession text, including an empty value.
  public let superseded: String?
  /// Provider-reported table units, such as meters or feet.
  public let units: String?

  private enum CodingKeys: String, CodingKey {
    case accepted
    case analysisPeriods = "DatumAnalysisPeriod"
    case controlStation = "ctrlStation"
    case datums
    case disclaimers
    case epoch
    case highestAstronomicalTide = "HAT"
    case highestAstronomicalTideDate = "HATdate"
    case highestAstronomicalTideTime = "HATtime"
    case leastAstronomicalTide = "LAT"
    case leastAstronomicalTideDate = "LATdate"
    case leastAstronomicalTideTime = "LATtime"
    case maximum = "max"
    case maximumDate = "maxdate"
    case maximumTime = "maxtime"
    case minimum = "min"
    case minimumDate = "mindate"
    case minimumTime = "mintime"
    case ngsLink = "NGSLink"
    case orthometricDatum = "OrthometricDatum"
    case selfLink = "self"
    case superseded
    case units
  }
}
