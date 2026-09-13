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
    case .loaded(let forecast, let hourlyForecast, let observation, let place):
      Section(place) {
        if let description = observation.textDescription, !description.isEmpty {
          LabeledContent("Conditions", value: description)
        }
        LabeledContent("Temperature", value: observation.temperature.displayText)
        LabeledContent("Humidity", value: observation.relativeHumidity.displayText)
        LabeledContent("Wind", value: observation.windSpeed.displayText)
        LabeledContent("Station", value: observation.stationName ?? observation.stationId)
        LabeledContent("Observed") {
          Text(observation.timestamp, format: .dateTime.hour().minute())
        }
      }
      Section("Forecast") {
        ForEach(forecast.periods, id: \.number) { period in
          VStack(alignment: .leading) {
            Text(period.name ?? "Forecast").font(.headline)
            Text(period.detailedForecast)
          }
        }
      }
      Section("Next 24 Hours") {
        ForEach(Array(hourlyForecast.periods.prefix(24)), id: \.number) { period in
          VStack(alignment: .leading) {
            Text(period.startTime, format: .dateTime.weekday().hour()).font(.headline)
            Text(period.shortForecast)
          }
        }
      }
    case .failed(let message):
      Section { Text(message).foregroundStyle(.red) }
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
    guard let quantity = self, let value = quantity.value else { return "Not reported" }
    let wholeNumber = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    switch quantity.unitCode {
    case "wmoUnit:degC":
      return Measurement(value: value, unit: UnitTemperature.celsius)
        .formatted(
          .measurement(width: .abbreviated, usage: .weather, numberFormatStyle: wholeNumber))
    case "wmoUnit:km_h-1":
      return Measurement(value: value, unit: UnitSpeed.kilometersPerHour)
        .formatted(.measurement(width: .abbreviated, usage: .wind, numberFormatStyle: wholeNumber))
    case "wmoUnit:percent":
      return (value / 100).formatted(.percent.precision(.fractionLength(0)))
    default:
      return "\(value.formatted()) \(quantity.unitCode)"
    }
  }
}

#Preview {
  ContentView()
}
