#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A single JSON operation on the HTTPS CO-OPS origin.
///
/// Paths are immutable and validated. Use `TidesEndpoint<MyResponse>(path:)` for custom responses.
public struct TidesEndpoint<Response>: Hashable, Sendable {
  /// The exact encoded path and query relative to the CO-OPS origin.
  public let path: String

  /// Creates an endpoint from an HTTPS CO-OPS link without credentials or a fragment.
  /// - Parameter link: The provider link. Only the default port is accepted.
  public init?(link: URL) {
    guard let components = URLComponents(url: link, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == "https",
      components.host?.lowercased() == "api.tidesandcurrents.noaa.gov",
      components.port == nil || components.port == 443,
      components.user == nil, components.password == nil, components.fragment == nil
    else { return nil }
    self.init(
      path: components.percentEncodedPath + (components.percentEncodedQuery.map { "?" + $0 } ?? ""))
  }

  /// Creates an endpoint from an encoded absolute-path reference and optional query.
  /// Raw controls, malformed escapes, authority forms, backslashes, and dot segments are refused.
  /// - Parameter path: A path beginning with one slash, retained without normalization.
  public init?(path: String) {
    guard Self.isValidPath(path) else { return nil }
    self.path = path
  }

  package func decoding<Value>(_ type: Value.Type) -> TidesEndpoint<Value> {
    TidesEndpoint<Value>.builtIn(path: path)
  }

  static func builtIn(path: String) -> Self {
    guard let result = Self(path: path) else {
      preconditionFailure("Fixed routes and encoded validated query values form valid paths.")
    }
    return result
  }

  static func query(_ items: [URLQueryItem]) -> String {
    var components = URLComponents()
    components.queryItems = items
    return components.percentEncodedQuery.map { "?" + $0 } ?? ""
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

extension TidesEndpoint where Response == CoastalStations {
  /// Retrieves one station's complete detail envelope without unwrapping.
  /// - Parameter identifier: A validated identifier whose case is retained.
  /// - Returns: The station-detail endpoint.
  public static func station(identifier: CoastalStationIdentifier) -> Self {
    builtIn(path: "/mdapi/prod/webapi/stations/\(identifier.rawValue).json")
  }

  /// Retrieves one directory response without expanding station resources.
  /// - Parameter query: The directory type.
  /// - Returns: The directory endpoint.
  public static func stations(matching query: CoastalStationQuery) -> Self {
    builtIn(
      path: "/mdapi/prod/webapi/stations.json"
        + Self.query([
          URLQueryItem(name: "type", value: query.type.rawValue)
        ]))
  }
}
