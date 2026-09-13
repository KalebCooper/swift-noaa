import SwiftNWS
import SwiftNWSTestSupport
import Testing

@Suite("NWSConfiguration", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct NWSConfigurationTests {
  @Test("The user agent is kept exactly as given")
  func theUserAgentIsKeptExactlyAsGiven() {
    let configuration = NWSConfiguration(userAgent: "(example.com, contact@example.com)")

    #expect(configuration.userAgent == "(example.com, contact@example.com)")
  }
}
