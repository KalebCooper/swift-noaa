#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One request to the National Weather Service API, described as plain values, and the type its
/// response decodes as.
///
/// An endpoint names a path relative to `https://api.weather.gov` and the media type to ask for. It
/// sends nothing itself: `SwiftNWS` sends it, or a networking stack of your own does, by requesting
/// ``path`` with ``accept`` in the `Accept` header and a `User-Agent` that identifies your
/// application, then decoding the body as `Response`.
///
/// ```swift
/// let location = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
/// let endpoint = Endpoint.point(for: location)
/// print(endpoint.path)  // "/points/30.2672,-97.7431"
/// ```
public struct Endpoint<Response>: Hashable, Sendable {
  /// The media type to name in the `Accept` header.
  public var accept: MediaType

  /// The comma-separated values to send in the Feature-Flags header.
  public var featureFlags: [NWSFeatureFlag]

  /// The path, and query when there is one, relative to `https://api.weather.gov`.
  public var path: String

  /// Creates an endpoint from an HTTPS API link without credentials or a fragment.
  ///
  /// Returns `nil` for another origin, a nondefault port, credentials, a fragment, or no path.
  /// Explicit port 443 is accepted. Encoded paths and queries are retained.
  ///
  /// Responses link to related resources with absolute URLs. Follow them through this initializer
  /// rather than building the path again.
  ///
  /// ```swift
  /// let stations = Endpoint<FeatureCollection<ObservationStation>>(link: point.observationStations)
  /// ```
  ///
  /// - Parameters:
  ///   - accept: The media type to ask for; defaults to ``MediaType/geoJSON``.
  ///   - featureFlags: Explicit response representations to request.
  ///   - link: An absolute URL from a response.
  public init?(accept: MediaType = .geoJSON, featureFlags: [NWSFeatureFlag] = [], link: URL) {
    guard let components = URLComponents(url: link, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == "https",
      components.host?.lowercased() == "api.weather.gov",
      components.port == nil || components.port == 443,
      components.user == nil, components.password == nil,
      components.fragment == nil,
      components.percentEncodedPath.hasPrefix("/")
    else { return nil }
    let query = components.percentEncodedQuery.map { "?" + $0 } ?? ""
    self.init(
      accept: accept, featureFlags: featureFlags, path: components.percentEncodedPath + query)
  }

  /// Creates an endpoint from an API link using a consumer-defined feature flag enum.
  /// - Parameters:
  ///   - accept: The media type to ask for; defaults to ``MediaType/geoJSON``.
  ///   - featureFlags: String-backed response representations to request.
  ///   - link: An absolute URL from a response.
  public init?<Flag>(accept: MediaType = .geoJSON, featureFlags: [Flag], link: URL)
  where Flag: RawRepresentable, Flag.RawValue == String {
    var converted: [NWSFeatureFlag] = []
    converted.reserveCapacity(featureFlags.count)
    for featureFlag in featureFlags {
      converted.append(NWSFeatureFlag(featureFlag))
    }
    self.init(accept: accept, featureFlags: converted, link: link)
  }

  /// Creates an endpoint from a path.
  ///
  /// - Parameters:
  ///   - accept: The media type to ask for; defaults to ``MediaType/geoJSON``.
  ///   - featureFlags: Explicit response representations to request.
  ///   - path: The path relative to `https://api.weather.gov`, starting with `/`.
  public init(
    accept: MediaType = .geoJSON, featureFlags: [NWSFeatureFlag] = [], path: String
  ) {
    self.accept = accept
    self.featureFlags = featureFlags
    self.path = path
  }

  /// Creates an endpoint from a path using a consumer-defined feature flag enum.
  /// - Parameters:
  ///   - accept: The media type to ask for; defaults to ``MediaType/geoJSON``.
  ///   - featureFlags: String-backed response representations to request.
  ///   - path: The path relative to `https://api.weather.gov`, starting with `/`.
  public init<Flag>(accept: MediaType = .geoJSON, featureFlags: [Flag], path: String)
  where Flag: RawRepresentable, Flag.RawValue == String {
    var converted: [NWSFeatureFlag] = []
    converted.reserveCapacity(featureFlags.count)
    for featureFlag in featureFlags {
      converted.append(NWSFeatureFlag(featureFlag))
    }
    self.init(accept: accept, featureFlags: converted, path: path)
  }
}

extension Endpoint where Response == Feature<WeatherForecast> {
  /// Follows a point's twelve-hour forecast link with explicit options.
  /// - Parameters:
  ///   - point: The point whose forecast to retrieve.
  ///   - options: Units and representation flags.
  /// - Returns: A forecast endpoint, or nil for a disallowed link.
  public static func forecast(for point: Point, options: ForecastOptions = .init()) -> Self? {
    forecast(link: point.forecast, options: options)
  }

  /// Follows a point's hourly forecast link with explicit options.
  /// - Parameters:
  ///   - point: The point whose hourly forecast to retrieve.
  ///   - options: Units and representation flags.
  /// - Returns: An hourly endpoint, or nil for a disallowed link.
  public static func hourlyForecast(for point: Point, options: ForecastOptions = .init()) -> Self? {
    forecast(link: point.forecastHourly, options: options)
  }

  private static func forecast(link: URL, options: ForecastOptions) -> Self? {
    guard
      var endpoint = Self(
        featureFlags: options.featureFlags.sorted { $0.rawValue < $1.rawValue }, link: link),
      var components = URLComponents(string: endpoint.path)
    else { return nil }
    var items = components.percentEncodedQueryItems ?? []
    items.removeAll { $0.name == "units" }
    items.append(URLQueryItem(name: "units", value: options.units.rawValue))
    components.percentEncodedQueryItems = items
    guard let path = components.string else { return nil }
    endpoint.path = path
    return endpoint
  }
}

extension Endpoint where Response == Feature<WeatherObservation> {
  /// The most recent observation from a station, `/stations/{stationId}/observations/latest`.
  ///
  /// ```swift
  /// Endpoint.latestObservation(stationIdentifier: "KATT").path
  /// // "/stations/KATT/observations/latest"
  /// ```
  ///
  /// - Parameter stationIdentifier: The station's identifier, such as `KATT`. It is encoded as
  ///   one path segment. Callers of this low-level factory must supply a nonempty identifier.
  /// - Returns: The endpoint.
  public static func latestObservation(stationIdentifier: String) -> Endpoint {
    let encoded = stationIdentifier.utf8.map { byte -> String in
      switch byte {
      case 45, 48...57, 65...90, 95, 97...122, 126:
        String(UnicodeScalar(byte))
      default:
        "%" + (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
      }
    }.joined()
    return Endpoint(path: "/stations/\(encoded)/observations/latest")
  }
}

extension Endpoint where Response == FeatureCollection<WeatherObservation> {
  /// The observation-history page described by a validated query,
  /// `/stations/{stationId}/observations`.
  ///
  /// ```swift
  /// let query = try ObservationQuery(limit: 24, stationIdentifier: "KATT")
  /// Endpoint.observations(query: query).path  // "/stations/KATT/observations?limit=24"
  /// ```
  ///
  /// - Parameter query: The station, window, page size, and optional initial cursor.
  /// - Returns: One endpoint for the history page.
  public static func observations(query: ObservationQuery) -> Self {
    Self(
      path: "/stations/" + encodedSegment(query.stationIdentifier) + "/observations" + query.query)
  }
}

extension Endpoint where Response == FeatureCollection<ObservationStation> {
  /// The observation stations usable for a point, followed from the point's link.
  ///
  /// - Parameter point: The point whose stations to list.
  /// - Returns: The endpoint, or `nil` when the link is rejected by ``init(accept:featureFlags:link:)-(_,[NWSFeatureFlag],_)``.
  public static func observationStations(near point: Point) -> Endpoint? {
    Endpoint(link: point.observationStations)
  }

  /// The station-directory page described by a validated query.
  /// - Parameter query: Filters, page size, and optional initial cursor.
  /// - Returns: One endpoint for the directory page.
  public static func observationStations(query: ObservationStationQuery) -> Self {
    Self(path: "/stations" + query.query)
  }
}

extension Endpoint where Response == Feature<Point> {
  /// The forecast grid and links for a location, `/points/{latitude},{longitude}`.
  ///
  /// Both coordinates are rounded to four decimal places, which is the precision the API accepts
  /// without redirecting.
  ///
  /// ```swift
  /// Endpoint.point(for: location).path  // "/points/30.2672,-97.7431"
  /// ```
  ///
  /// - Parameter location: A validated, normalized coordinate.
  /// - Returns: The endpoint.
  public static func point(for location: WeatherCoordinate) -> Endpoint {
    Endpoint(path: "/points/\(coordinate(location.latitude)),\(coordinate(location.longitude))")
  }

  // Written with integer arithmetic rather than a number formatter, so the result is the same
  // on every platform and in every locale, and never uses exponent notation.
  private static func coordinate(_ degrees: Double) -> String {
    let scale = 10_000
    let tenThousandths = Int((degrees * Double(scale)).rounded())
    let sign = tenThousandths < 0 ? "-" : ""
    let whole = tenThousandths.magnitude / UInt(scale)
    let fraction = tenThousandths.magnitude % UInt(scale)
    guard fraction != 0 else { return "\(sign)\(whole)" }
    var digits = String(fraction)
    while digits.count < 4 { digits = "0" + digits }
    while digits.hasSuffix("0") { digits.removeLast() }
    return "\(sign)\(whole).\(digits)"
  }
}
