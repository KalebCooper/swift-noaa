#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
// The SDK's public API names HTTPCore's types (`TransportError` in this error, `Transport` in the
// client's initializer), so the module is re-exported: a consumer reads a transport failure's members
// under member import visibility without importing a module it never declared a dependency on.
@_exported import HTTPCore
import SwiftNWSModels

/// Why a request to the National Weather Service API failed.
///
/// ```swift
/// do {
///   let observation = try await client.latestObservation(latitude: 30.2672, longitude: -97.7431)
/// } catch {
///   switch error {
///   case .invalidLink(let link): report("Unexpected link: \(link)")
///   case .noObservationStation: report("No station reports near here.")
///   case .problem(let problem): report(problem.title)
///   case .transport(let failure): report(failure.description)
///   }
/// }
/// ```
public enum NWSError: Error {
  /// A response linked to a URL outside `https://api.weather.gov`, so the link was not followed.
  case invalidLink(URL)

  /// The point lists no observation station to read conditions from.
  case noObservationStation

  /// The API refused the request and explained why.
  case problem(ProblemDetail)

  /// The request failed without problem details: no response arrived, the status was an error with
  /// a body that is not problem details, or the body did not decode.
  case transport(TransportError)

  init(_ failure: TransportError) {
    if case .httpStatus(let body, _, _) = failure,
      let problem = try? JSONDecoder().decode(ProblemDetail.self, from: body)
    {
      self = .problem(problem)
    } else {
      self = .transport(failure)
    }
  }
}
