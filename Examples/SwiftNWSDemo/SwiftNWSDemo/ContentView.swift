import SwiftNWS
import SwiftNWSModels
import SwiftUI

struct ContentView: View {
  @State private var address = ""
  @State private var model = ConditionsModel()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Address", text: $address)
            .textContentType(.fullStreetAddress)
            .submitLabel(.search)
            .onSubmit(search)
          Button("Search", systemImage: "magnifyingglass", action: search)
            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
          Button("Use My Location", systemImage: "location") {
            Task { await model.useMyLocation() }
          }
        }
        .disabled(model.phase == .loading)

        conditions
      }
      .navigationTitle("Weather")
    }
  }

  @ViewBuilder
  private var conditions: some View {
    switch model.phase {
    case .idle:
      EmptyView()
    case .loading:
      Section { ProgressView() }
    case .loaded(let alerts, let forecast, let hourlyForecast, let observation, let place):
      Section(place) {
        if let description = observation.textDescription, !description.isEmpty {
          LabeledContent("Conditions", value: description)
        }
        LabeledContent("Temperature", value: observation.temperature.displayText)
        LabeledContent("Humidity", value: observation.relativeHumidity.displayText)
        LabeledContent("Wind", value: observation.windSpeed.displayText)
        if let weather = observation.presentWeather, !weather.isEmpty {
          LabeledContent("Present Weather", value: weather.map(\.rawString).joined(separator: " "))
        }
        if let layers = observation.cloudLayers, !layers.isEmpty {
          LabeledContent("Sky", value: layers.map(\.amount.rawValue).joined(separator: " "))
        }
        LabeledContent("Station", value: observation.stationName ?? observation.stationId)
        LabeledContent("Observed") {
          Text(observation.timestamp, format: .dateTime.hour().minute())
        }
      }
      Section("Active Alerts") {
        if alerts.features.isEmpty {
          Text("No active alerts returned for this location.")
        }
        ForEach(alerts.features, id: \.properties.id) { feature in
          let alert = feature.properties
          DisclosureGroup(alert.headline ?? alert.event) {
            Text(alert.description)
            if let instruction = alert.instruction, !instruction.isEmpty { Text(instruction) }
            LabeledContent("Category", value: alert.category.rawValue)
            LabeledContent("Response", value: alert.response.rawValue)
            LabeledContent("Severity", value: alert.severity.rawValue)
            LabeledContent("Expires") { Text(alert.expires, format: .dateTime) }
          }
        }
      }
      Section("Forecast") {
        ForEach(forecast.periods, id: \.number) { period in
          VStack(alignment: .leading) {
            Text(period.name ?? "Forecast").font(.headline)
            Text(period.detailedForecast)
            forecastMeasurements(period)
          }
        }
      }
      Section("Next 24 Hours") {
        ForEach(Array(hourlyForecast.periods.prefix(24)), id: \.number) { period in
          VStack(alignment: .leading) {
            Text(period.startTime, format: .dateTime.weekday().hour()).font(.headline)
            Text(period.shortForecast)
            forecastMeasurements(period)
          }
        }
      }
    case .failed(let message):
      Section { Text(message).foregroundStyle(.red) }
    }
  }

  @ViewBuilder
  private func forecastMeasurements(_ period: ForecastPeriod) -> some View {
    switch period.temperature {
    case .quantity(let temperature):
      LabeledContent("Temperature", value: Optional(temperature).displayText)
    case .value(let value):
      LabeledContent(
        "Temperature", value: "\(value.formatted()) \(period.temperatureUnit?.rawValue ?? "")")
    }
    switch period.windSpeed {
    case .quantity(let wind):
      LabeledContent("Wind", value: Optional(wind).displayText)
    case .text(let text):
      LabeledContent("Wind", value: text)
    }
  }

  private func search() {
    let address = address
    Task { await model.search(address: address) }
  }
}

extension QuantitativeValue? {
  /// The measurement formatted for the current locale, converting the units the API reports in.
  fileprivate var displayText: String {
    guard let quantity = self else { return "Not reported" }
    guard let value = quantity.value else {
      if let minimum = quantity.minValue, let maximum = quantity.maxValue {
        var lower = quantity
        var upper = quantity
        lower.value = minimum
        upper.value = maximum
        return "\(Optional(lower).displayText) to \(Optional(upper).displayText)"
      }
      return "Not reported"
    }
    let wholeNumber = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    if let temperature = quantity.measurement(in: UnitTemperature.celsius) {
      return temperature.formatted(
        .measurement(width: .abbreviated, usage: .weather, numberFormatStyle: wholeNumber))
    }
    if let wind = quantity.measurement(in: UnitSpeed.kilometersPerHour) {
      return wind.formatted(
        .measurement(width: .abbreviated, usage: .wind, numberFormatStyle: wholeNumber))
    }
    if let fraction = quantity.fraction {
      return fraction.formatted(.percent.precision(.fractionLength(0)))
    }
    return "\(value.formatted()) \(quantity.unitCode)"
  }
}

#Preview {
  ContentView()
}
