#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@_exported import HTTPCore
import SwiftNOAATidesModels

/// A CO-OPS execution failure, distinct from NWS problem details.
public enum TidesError: Error {
  /// The body failed strict model decoding.
  case decoding(any Error)
  /// An HTTP failure without a decoded provider refusal.
  case httpStatus(body: Data, code: Int)
  /// A redirect had a disallowed origin, credentials, fragment, or encoded path.
  case invalidLink(String)
  /// A locally invalid query argument was rejected before sending.
  case invalidQuery(TidesQueryError)
  /// A detail envelope was empty, plural, or did not match the requested identifier.
  case invalidStationResponse(expected: String, identifiers: [String], reportedCount: Int)
  /// The provider explicitly refused the query, even if it returned HTTP 200.
  case provider(TidesProviderError)
  /// A redirect loop or more than five hops prevented completion.
  case tooManyRedirects
  /// The transport failed; cancellation is represented by TransportError.cancelled.
  case transport(TransportError)
}
