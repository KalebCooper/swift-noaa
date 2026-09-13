import CoreLocation
import Foundation
import MapKit
import SwiftNWS
import SwiftNWSModels

/// Finds a location, by address or from the device, and loads the latest observation near it.
@MainActor
@Observable
final class ConditionsModel {
  enum Phase: Equatable {
    case failed(String)
    case idle
    case loaded(
      alerts: FeatureCollection<WeatherAlert>, forecast: WeatherForecast,
      hourlyForecast: WeatherForecast, observation: WeatherObservation,
      place: String)
    case loading
  }

  private(set) var phase = Phase.idle

  private let client = NWSClient(
    userAgent: "(SwiftNWSDemo, https://github.com/KalebCooper/swift-noaa)"
  )

  /// Geocodes an address with MapKit, since the National Weather Service API has no geocoding.
  func search(address: String) async {
    await load {
      guard let request = MKGeocodingRequest(addressString: address),
        let item = try await request.mapItems.first
      else {
        throw LocationError.noMatch(address)
      }
      return (item.name ?? address, item.location.coordinate)
    }
  }

  /// Reads one location from the device, asking for When In Use authorization if needed.
  func useMyLocation() async {
    await load {
      let session = CLServiceSession(authorization: .whenInUse)
      defer { session.invalidate() }
      for try await update in CLLocationUpdate.liveUpdates() {
        if let location = update.location {
          return (String(localized: "Current Location"), location.coordinate)
        }
        if update.authorizationDenied || update.authorizationDeniedGlobally {
          throw LocationError.denied
        }
      }
      throw LocationError.unavailable
    }
  }

  private func load(_ locate: () async throws -> (String, CLLocationCoordinate2D)) async {
    phase = .loading
    do {
      let (place, coordinate) = try await locate()
      let location = try WeatherCoordinate(
        latitude: coordinate.latitude, longitude: coordinate.longitude)
      let alerts = try await client.activeAlerts(for: location)
      let observation = try await client.latestObservation(from: .nearest(to: location))
      let forecast = try await client.forecast(for: location)
      let hourlyForecast = try await client.hourlyForecast(for: location)
      phase = .loaded(
        alerts: alerts, forecast: forecast, hourlyForecast: hourlyForecast,
        observation: observation, place: place)
    } catch let error as NWSError {
      phase = .failed(Self.message(for: error))
    } catch is WeatherCoordinate.ValidationError {
      phase = .failed("The location has invalid coordinates.")
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  private static func message(for error: NWSError) -> String {
    switch error {
    case .invalidAlertIdentifier: "The weather service returned an empty alert identifier."
    case .invalidLink(let link): "The API linked outside itself: \(link)"
    case .invalidRedirect: "The weather service returned an invalid redirect."
    case .invalidStationIdentifier: "The weather service returned an empty station identifier."
    case .noObservationStation: "No weather station reports near this location."
    case .problem(let problem): "\(problem.title): \(problem.detail)"
    case .tooManyRedirects: "The weather service redirected too many times. Try again later."
    case .transport(let failure): failure.description
    }
  }
}

private enum LocationError: LocalizedError {
  case denied
  case noMatch(String)
  case unavailable

  var errorDescription: String? {
    switch self {
    case .denied: "Location access is off. Turn it on in Settings, or search for an address."
    case .noMatch(let address): "No place matches \"\(address)\"."
    case .unavailable: "The device's location is unavailable."
    }
  }
}
