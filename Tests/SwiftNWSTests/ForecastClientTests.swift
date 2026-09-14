import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Forecast client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ForecastClientTests {
  @Test("Cancellation after the point prevents the forecast request")
  func cancellationAfterThePointPreventsTheForecastRequest() async throws {
    let transport = MockTransport()
    let body = try Fixture.point.data()
    transport.setHandler(forPath: "/points/30.2672,-97.7431") { _ in
      withUnsafeCurrentTask { $0?.cancel() }
      return .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    let work = Task {
      await #expect(throws: NWSError.self) { try await client.forecast(for: location) }
    }
    guard case .transport(.cancelled) = await work.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("Forecast calls follow links and share results", arguments: [false, true], [false, true])
  func forecastCallsFollowLinksAndShareResults(hourly: Bool, useRequest: Bool) async throws {
    let transport = MockTransport()
    let pointBody = try Fixture.point.data()
    let fixture: Fixture = hourly ? .hourlyForecastQuantities : .forecastQuantities
    let forecastBody = try fixture.data()
    transport.setHandler(forPath: "/points/30.2672,-97.7431") { _ in
      .success(MockTransport.Answer(Response(body: pointBody, status: .ok)))
    }
    let path = hourly ? "/gridpoints/EWX/156,91/forecast/hourly" : "/gridpoints/EWX/156,91/forecast"
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: forecastBody, status: .ok)))
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    let options = ForecastOptions(
      featureFlags: [.temperatureQuantity, .windSpeedQuantity], units: .si)
    let result: WeatherForecast
    if useRequest {
      let request =
        hourly
        ? WeatherRequest.hourlyForecast(for: location, options: options)
        : .forecast(for: location, options: options)
      result = try await client.value(for: request)
    } else if hourly {
      result = try await client.hourlyForecast(for: location, options: options)
    } else {
      result = try await client.forecast(for: location, options: options)
    }
    let recorded = try JSONDecoder().decode(Feature<WeatherForecast>.self, from: forecastBody)
    #expect(result == recorded.properties)
    #expect(
      transport.requests.map(\.request.path) == ["/points/30.2672,-97.7431", path + "?units=si"])
    let sent = try #require(transport.requests.last)
    #expect(sent.request.url?.query == "units=si")
    let flagName = try #require(HTTPField.Name("Feature-Flags"))
    #expect(sent.request.headerFields[flagName] == "forecast_temperature_qv,forecast_wind_speed_qv")
    #expect(transport.requests.first?.request.headerFields[flagName] == nil)
  }

  @Test("Forecast factories infer reusable responses without sending")
  func forecastFactoriesInferReusableResponsesWithoutSending() throws {
    let transport = MockTransport()
    let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    let forecast = WeatherRequest.forecast(for: location)
    let hourly = WeatherRequest.hourlyForecast(for: location, options: .init(units: .si))
    #expect(forecast == .forecast(for: location))
    #expect(hourly == .hourlyForecast(for: location, options: .init(units: .si)))
    #expect(transport.requests.isEmpty)
  }

  private func callSites(_ client: NWSClient, location: WeatherCoordinate, point: Point)
    async throws
  {
    let _: WeatherForecast = try await client.forecast(for: location)
    let _: WeatherForecast = try await client.hourlyForecast(for: location)
    let _: WeatherForecast = try await client.value(for: .forecast(for: location))
    let _: WeatherForecast = try await client.value(for: .hourlyForecast(for: location))
    let _: WeatherForecast = try await client.value(for: .austinForecast)
    let endpoint = try #require(Endpoint.forecast(for: point))
    let _: Feature<WeatherForecast> = try await client.send(endpoint)
    let custom = WeatherRequest(endpoint: Endpoint<ForecastIdentity>(path: "/custom"))
    let _: ForecastIdentity = try await client.value(for: custom)
  }
}

private struct ForecastIdentity: Decodable, Sendable {
  let id: String
}

extension WeatherRequest where Response == WeatherForecast {
  fileprivate static var austinForecast: Self {
    get throws {
      .forecast(for: try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431))
    }
  }
}
