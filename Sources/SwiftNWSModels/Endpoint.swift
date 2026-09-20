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

  /// The validated encoded path and optional query, relative to `https://api.weather.gov`.
  /// The exact spelling is retained and cannot be changed after initialization.
  public let path: String

  /// Creates an endpoint from an HTTPS API link without credentials or a fragment.
  ///
  /// Returns `nil` for another origin, a nondefault port, credentials, a fragment, no path, or an invalid relative path.
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

  /// Creates an endpoint from an encoded relative API path and optional query.
  ///
  /// Returns nil for absolute or authority URLs, fragments, raw whitespace or controls,
  /// malformed percent escapes, backslashes, or dot path segments. Encoded authority forms,
  /// backslashes, controls, and dot segments within the path are also rejected.
  /// Encoded spaces and Unicode are allowed. Query values are not interpreted as path segments.
  /// Accepted text is retained exactly, without normalization.
  ///
  /// - Parameters:
  ///   - accept: The media type to ask for; defaults to ``MediaType/geoJSON``.
  ///   - featureFlags: Explicit response representations to request.
  ///   - path: The path relative to `https://api.weather.gov`, starting with `/`.
  public init?(
    accept: MediaType = .geoJSON, featureFlags: [NWSFeatureFlag] = [], path: String
  ) {
    guard Self.isValidPath(path) else { return nil }
    self.accept = accept
    self.featureFlags = featureFlags
    self.path = path
  }

  /// Creates an endpoint from a validated path using a consumer-defined feature flag enum.
  /// Returns nil under the same rules as the raw-path initializer.
  /// - Parameters:
  ///   - accept: The media type to ask for; defaults to ``MediaType/geoJSON``.
  ///   - featureFlags: String-backed response representations to request.
  ///   - path: The path relative to `https://api.weather.gov`, starting with `/`.
  public init?<Flag>(accept: MediaType = .geoJSON, featureFlags: [Flag], path: String)
  where Flag: RawRepresentable, Flag.RawValue == String {
    var converted: [NWSFeatureFlag] = []
    converted.reserveCapacity(featureFlags.count)
    for featureFlag in featureFlags {
      converted.append(NWSFeatureFlag(featureFlag))
    }
    self.init(accept: accept, featureFlags: converted, path: path)
  }

  // Encodes one path argument as exactly one segment: only unreserved characters pass through, so
  // a slash, question mark, or percent in an identifier cannot change the route.
  static func encodedSegment(_ value: String) -> String {
    value.utf8.map { byte -> String in
      switch byte {
      case 45, 48...57, 65...90, 95, 97...122, 126:
        String(UnicodeScalar(byte))
      default:
        "%" + (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
      }
    }.joined()
  }

  // Only fixed paths, validated domain values, and encoded queries use this construction.
  // Validation still runs so there is no alternate unchecked endpoint representation.
  static func builtIn(accept: MediaType = .geoJSON, path: String) -> Self {
    guard let endpoint = Self(accept: accept, path: path) else {
      preconditionFailure("Fixed API paths with validated segments and encoded queries are valid.")
    }
    return endpoint
  }

  private static func decoded(_ value: String) -> String? {
    let bytes = Array(value.utf8)
    var decoded: [UInt8] = []
    var index = 0
    while index < bytes.count {
      if bytes[index] == 37 {
        guard index + 2 < bytes.count,
          let byte = UInt8(
            String(decoding: bytes[(index + 1)...(index + 2)], as: UTF8.self), radix: 16)
        else { return nil }
        decoded.append(byte)
        index += 3
      } else {
        decoded.append(bytes[index])
        index += 1
      }
    }
    return String(validating: decoded, as: UTF8.self)
  }

  private static func isValidPath(_ value: String) -> Bool {
    guard value.hasPrefix("/"), !value.hasPrefix("//") else { return false }
    let bytes = Array(value.utf8)
    var index = 0
    var inQuery = false
    while index < bytes.count {
      let byte = bytes[index]
      if byte == 63 { inQuery = true }
      let allowed =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~!$&'()*+,;=:@/?%"
      guard allowed.utf8.contains(byte) || (inQuery && (byte == 91 || byte == 93)) else {
        return false
      }
      if byte == 37 {
        guard index + 2 < bytes.count,
          UInt8(String(UnicodeScalar(bytes[index + 1])), radix: 16) != nil,
          UInt8(String(UnicodeScalar(bytes[index + 2])), radix: 16) != nil
        else { return false }
        index += 3
      } else {
        index += 1
      }
    }
    let path = value.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
    guard let decoded = decoded(String(path)),
      !decoded.hasPrefix("//"),
      !decoded.unicodeScalars.contains(where: {
        $0.properties.generalCategory == .control || $0 == "\\"
      })
    else { return false }
    return !decoded.split(separator: "/").contains { $0 == "." || $0 == ".." }
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
      let endpoint = Self(
        featureFlags: options.featureFlags.sorted { $0.rawValue < $1.rawValue }, link: link)
    else { return nil }
    let parts = endpoint.path.split(
      separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
    var items: [String] = []
    if parts.count == 2, !parts[1].isEmpty {
      items = parts[1].split(separator: "&", omittingEmptySubsequences: false).map(String.init)
      items.removeAll {
        let name = $0.split(
          separator: "=", maxSplits: 1, omittingEmptySubsequences: false)[0]
        return decoded(String(name)) == "units"
      }
    }
    let units = URLComponents.nwsQuery([URLQueryItem(name: "units", value: options.units.rawValue)])
    items.append(String(units.dropFirst()))
    return Self(
      accept: endpoint.accept, featureFlags: endpoint.featureFlags,
      path: String(parts[0]) + "?" + items.joined(separator: "&"))
  }
}

extension Endpoint where Response == Feature<ForecastGrid> {
  /// Follows a point's raw forecast grid data link, `/gridpoints/{wfo}/{x},{y}`.
  ///
  /// The endpoint asks for GeoJSON and sends no units query or feature flags: the service accepts
  /// neither for grid data and answers a `units` query with `400`. The link's path is kept exactly;
  /// the office identifier in it is case sensitive.
  ///
  /// ```swift
  /// Endpoint.forecastGrid(for: point)?.path  // "/gridpoints/EWX/156,91"
  /// ```
  ///
  /// - Parameter point: The point whose grid data to retrieve.
  /// - Returns: The endpoint, or `nil` when the link is rejected by ``init(accept:featureFlags:link:)-(_,[NWSFeatureFlag],_)``.
  public static func forecastGrid(for point: Point) -> Self? {
    Self(link: point.forecastGridData)
  }
}

extension Endpoint where Response == Feature<WeatherObservation> {
  /// The most recent observation from a station, `/stations/{stationId}/observations/latest`.
  ///
  /// ```swift
  /// Endpoint.latestObservation(stationIdentifier: "KATT")?.path
  /// // "/stations/KATT/observations/latest"
  /// ```
  ///
  /// - Parameter stationIdentifier: The station's identifier, such as `KATT`. It is encoded as
  ///   one path segment. Empty identifiers and invalid encoded paths are rejected.
  /// - Returns: The endpoint, or nil for an empty identifier or invalid path.
  public static func latestObservation(stationIdentifier: String) -> Endpoint? {
    guard !stationIdentifier.isEmpty else { return nil }
    return Endpoint(path: "/stations/" + encodedSegment(stationIdentifier) + "/observations/latest")
  }

  /// The observation a station made at an exact instant, `/stations/{stationId}/observations/{time}`.
  ///
  /// The instant is sent in ISO 8601 form in UTC with whole-second precision. The service returns
  /// an observation only when one has exactly that timestamp, such as a `timestamp` from observation
  /// history; any other instant, including one between two observations, answers `404` problem
  /// details rather than the nearest observation.
  ///
  /// ```swift
  /// let timestamp = Date(timeIntervalSince1970: 1_789_696_260)
  /// Endpoint.observation(stationIdentifier: "KATT", timestamp: timestamp)?.path
  /// // "/stations/KATT/observations/2026-09-18T01:51:00Z"
  /// ```
  ///
  /// - Parameters:
  ///   - stationIdentifier: The station's identifier, such as `KATT`. It is encoded as one path
  ///     segment. Empty identifiers and invalid encoded paths are rejected.
  ///   - timestamp: The observation's exact timestamp.
  /// - Returns: The endpoint, or nil for an empty identifier or invalid path.
  public static func observation(stationIdentifier: String, timestamp: Date) -> Endpoint? {
    guard !stationIdentifier.isEmpty else { return nil }
    return Endpoint(
      path: "/stations/" + encodedSegment(stationIdentifier) + "/observations/"
        + timestamp.formatted(.iso8601))
  }
}

extension Endpoint where Response == Feature<ObservationStation> {
  /// The metadata for one observation station, `/stations/{stationId}`.
  ///
  /// ```swift
  /// Endpoint.observationStation(identifier: "KATT")?.path  // "/stations/KATT"
  /// ```
  ///
  /// - Parameter identifier: The station's identifier, such as `KATT`. It is encoded as one path
  ///   segment. Empty identifiers and invalid encoded paths are rejected.
  /// - Returns: The endpoint, or nil for an empty identifier or invalid path.
  public static func observationStation(identifier: String) -> Self? {
    guard !identifier.isEmpty else { return nil }
    return Self(path: "/stations/" + encodedSegment(identifier))
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
    builtIn(
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
    builtIn(path: "/stations" + query.query)
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
    builtIn(path: "/points/\(coordinate(location.latitude)),\(coordinate(location.longitude))")
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
