#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A National Weather Service forecast office, as `/offices/{officeId}` describes it.
///
/// The identifier and name are always present. Every other field is optional because the service
/// can omit or null it. Values are kept as the service sends them, including an empty fax number
/// and an office whose zone or station lists are absent. The zone, station, and parent office
/// fields are links to other API resources; follow them with
/// ``Endpoint/init(accept:featureFlags:link:)-(_,[ForecastFeatureFlag],_)`` rather than rebuilding
/// their paths.
///
/// ```swift
/// let office = try await weather.office(identifier: "EWX")
/// print(office.id, office.name)  // "EWX Austin/San Antonio, TX"
/// ```
public struct WeatherOffice: Codable, Hashable, Sendable {
  /// The office's postal address, or nil when the service sends none.
  public var address: Address?

  /// Links to the observation stations the office approves, in the order the service listed them.
  public var approvedObservationStations: [URL]?

  /// The office's contact email address, such as `sr-ewx.webmaster@noaa.gov`.
  public var email: String?

  /// The office's fax number, which the service sends as an empty string for some offices and is
  /// kept exactly as sent.
  public var faxNumber: String?

  /// The office's identifier, such as `EWX`.
  public var id: String

  /// The office's name, such as `Austin/San Antonio, TX`.
  public var name: String

  /// The National Weather Service region code the office reports, such as `sr`.
  public var nwsRegion: String?

  /// A link to the regional headquarters the office reports to.
  public var parentOrganization: URL?

  /// Links to the county zones the office is responsible for, in the order the service listed them.
  public var responsibleCounties: [URL]?

  /// Links to the fire weather zones the office is responsible for, in the order the service
  /// listed them.
  public var responsibleFireZones: [URL]?

  /// Links to the public forecast zones the office is responsible for, in the order the service
  /// listed them.
  public var responsibleForecastZones: [URL]?

  /// The office's public website, such as `https://www.weather.gov/ewx`, kept exactly as the
  /// service sends it.
  ///
  /// The website is outside the API origin and the SDK never sends a request to it. It is text
  /// rather than a `URL` so that an empty or malformed value is preserved and never fails the office
  /// to decode.
  public var sameAs: String?

  /// The office's telephone number, spelled as the service sends it.
  public var telephone: String?

  /// The office's own API identity URL, from the response's `@id`.
  public var url: URL?

  /// Creates an office.
  ///
  /// - Parameters:
  ///   - address: The office's postal address.
  ///   - approvedObservationStations: Links to the observation stations the office approves.
  ///   - email: The office's contact email address.
  ///   - faxNumber: The office's fax number.
  ///   - id: The office's identifier.
  ///   - name: The office's name.
  ///   - nwsRegion: The National Weather Service region code the office reports.
  ///   - parentOrganization: A link to the regional headquarters the office reports to.
  ///   - responsibleCounties: Links to the county zones the office is responsible for.
  ///   - responsibleFireZones: Links to the fire weather zones the office is responsible for.
  ///   - responsibleForecastZones: Links to the public forecast zones the office is responsible for.
  ///   - sameAs: The office's public website.
  ///   - telephone: The office's telephone number.
  ///   - url: The office's own API identity URL.
  public init(
    address: Address? = nil,
    approvedObservationStations: [URL]? = nil,
    email: String? = nil,
    faxNumber: String? = nil,
    id: String,
    name: String,
    nwsRegion: String? = nil,
    parentOrganization: URL? = nil,
    responsibleCounties: [URL]? = nil,
    responsibleFireZones: [URL]? = nil,
    responsibleForecastZones: [URL]? = nil,
    sameAs: String? = nil,
    telephone: String? = nil,
    url: URL? = nil
  ) {
    self.address = address
    self.approvedObservationStations = approvedObservationStations
    self.email = email
    self.faxNumber = faxNumber
    self.id = id
    self.name = name
    self.nwsRegion = nwsRegion
    self.parentOrganization = parentOrganization
    self.responsibleCounties = responsibleCounties
    self.responsibleFireZones = responsibleFireZones
    self.responsibleForecastZones = responsibleForecastZones
    self.sameAs = sameAs
    self.telephone = telephone
    self.url = url
  }

  /// The postal address of a forecast office.
  ///
  /// Every field is optional because the service describes them as optional properties. The text
  /// is kept as sent; this package does not format, localize, or geocode an address.
  ///
  /// ```swift
  /// let address = WeatherOffice.Address(
  ///   addressLocality: "New Braunfels", addressRegion: "TX", postalCode: "78130",
  ///   streetAddress: "2090 Airport Road")
  /// ```
  public struct Address: Codable, Hashable, Sendable {
    /// The city or town, such as `New Braunfels`.
    public var addressLocality: String?

    /// The state or territory code, such as `TX`.
    public var addressRegion: String?

    /// The postal code, such as `78130`.
    public var postalCode: String?

    /// The street address, such as `2090 Airport Road`.
    public var streetAddress: String?

    /// Creates a postal address.
    ///
    /// - Parameters:
    ///   - addressLocality: The city or town.
    ///   - addressRegion: The state or territory code.
    ///   - postalCode: The postal code.
    ///   - streetAddress: The street address.
    public init(
      addressLocality: String? = nil,
      addressRegion: String? = nil,
      postalCode: String? = nil,
      streetAddress: String? = nil
    ) {
      self.addressLocality = addressLocality
      self.addressRegion = addressRegion
      self.postalCode = postalCode
      self.streetAddress = streetAddress
    }
  }

  private enum CodingKeys: String, CodingKey {
    case address
    case approvedObservationStations
    case email
    case faxNumber
    case id
    case name
    case nwsRegion
    case parentOrganization
    case responsibleCounties
    case responsibleFireZones
    case responsibleForecastZones
    case sameAs
    case telephone
    case url = "@id"
  }
}
