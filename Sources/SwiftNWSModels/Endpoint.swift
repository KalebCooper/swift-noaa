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
/// let endpoint = Endpoint.point(latitude: 30.26721, longitude: -97.74306)
/// print(endpoint.path)  // "/points/30.2672,-97.7431"
/// ```
public struct Endpoint<Response>: Hashable, Sendable {
  /// The media type to name in the `Accept` header.
  public var accept: MediaType

  /// The path, and query when there is one, relative to `https://api.weather.gov`.
  public var path: String

  /// Creates an endpoint from a path.
  ///
  /// - Parameters:
  ///   - accept: The media type to ask for; defaults to ``MediaType/geoJSON``.
  ///   - path: The path relative to `https://api.weather.gov`, starting with `/`.
  public init(accept: MediaType = .geoJSON, path: String) {
    self.accept = accept
    self.path = path
  }

  /// Creates an endpoint from a link the API returned, or `nil` when the link is not on
  /// `https://api.weather.gov`.
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
  ///   - link: An absolute URL from a response.
  public init?(accept: MediaType = .geoJSON, link: URL) {
    let origin = "https://api.weather.gov"
    let absolute = link.absoluteString
    guard absolute.hasPrefix(origin) else { return nil }
    let path = String(absolute.dropFirst(origin.count))
    guard path.hasPrefix("/") else { return nil }
    self.init(accept: accept, path: path)
  }
}

extension Endpoint where Response == Feature<Point> {
  /// The forecast grid and links for a location, `/points/{latitude},{longitude}`.
  ///
  /// Both coordinates are rounded to four decimal places, which is the precision the API accepts
  /// without redirecting.
  ///
  /// ```swift
  /// Endpoint.point(latitude: 30.26721, longitude: -97.74306).path  // "/points/30.2672,-97.7431"
  /// ```
  ///
  /// - Parameters:
  ///   - latitude: The latitude in decimal degrees. It must be finite.
  ///   - longitude: The longitude in decimal degrees. It must be finite.
  /// - Returns: The endpoint.
  public static func point(latitude: Double, longitude: Double) -> Endpoint {
    Endpoint(path: "/points/\(coordinate(latitude)),\(coordinate(longitude))")
  }

  // Written with integer arithmetic rather than a number formatter, so the result is the same
  // on every platform and in every locale, and never uses exponent notation.
  private static func coordinate(_ degrees: Double) -> String {
    precondition(degrees.isFinite, "A coordinate must be finite.")
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

extension Endpoint where Response == FeatureCollection<ObservationStation> {
  /// The observation stations near a point, nearest first, followed from the point's link.
  ///
  /// - Parameter point: The point whose stations to list.
  /// - Returns: The endpoint, or `nil` when the point links somewhere other than
  ///   `https://api.weather.gov`.
  public static func observationStations(near point: Point) -> Endpoint? {
    Endpoint(link: point.observationStations)
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
  /// - Parameter stationIdentifier: The station's identifier, such as `KATT`.
  /// - Returns: The endpoint.
  public static func latestObservation(stationIdentifier: String) -> Endpoint {
    Endpoint(path: "/stations/\(stationIdentifier)/observations/latest")
  }
}
