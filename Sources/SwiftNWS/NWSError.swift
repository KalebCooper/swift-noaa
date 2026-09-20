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
///   let observation = try await client.latestObservation(from: .station("KATT"))
/// } catch {
///   switch error {
///   case .invalidAlertIdentifier: report("An alert identifier is required.")
///   case .invalidAlertLocation: report("A valid alert location is required.")
///   case .invalidLink(let link): report("Unexpected link: \(link)")
///   case .invalidRedirect: report("The API returned an invalid redirect.")
///   case .invalidStationIdentifier: report("A station identifier is required.")
///   case .noObservationStation: report("No station reports near here.")
///   case .pagination(let failure): report("Pagination failed: \(failure)")
///   case .problem(let problem): report(problem.title)
///   case .tooManyRedirects: report("The API redirected too many times.")
///   case .transport(let failure): report(failure.description)
///   }
/// }
/// ```
public enum NWSError: Error {
  /// The alert identifier is empty or produces an invalid encoded path, so no request was sent.
  case invalidAlertIdentifier(String)

  /// An area, region, or zone code is empty or produces an invalid encoded path.
  case invalidAlertLocation(String)

  /// A response contained a disallowed service URL, so the link was not followed.
  ///
  /// Links must use the HTTPS API origin without credentials or a fragment.
  case invalidLink(URL)

  /// A redirect Location could not be interpreted as a URL.
  case invalidRedirect(String)

  /// The station identifier is empty or produces an invalid encoded path, so no station or observation request was sent.
  case invalidStationIdentifier(String)

  /// The point lists no observation station to read conditions from.
  case noObservationStation

  /// A collection could not continue because its pagination metadata was unusable.
  case pagination(NWSPaginationError)

  /// The API refused the request and explained why.
  case problem(ProblemDetail)

  /// A redirect loop or more than five redirects prevented completion.
  case tooManyRedirects

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
