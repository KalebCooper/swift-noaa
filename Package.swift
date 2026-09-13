// swift-tools-version:6.2

import PackageDescription

// Two products, one dependency direction: SwiftNWSModels describes the National Weather Service API
// and depends on nothing, so a consumer with a networking stack of its own can take it alone, and
// SwiftNWS sends those descriptions through swifty-networking.
let package = Package(
  name: "swift-nws",
  platforms: [
    .iOS(.v26), .macOS(.v26), .tvOS(.v26), .visionOS(.v26), .watchOS(.v26),
  ],
  products: [
    .library(name: "SwiftNWS", targets: ["SwiftNWS"]),
    .library(name: "SwiftNWSModels", targets: ["SwiftNWSModels"]),
  ],
  traits: [
    // Nothing is on by default, stated at the declaration site rather than left to SwiftPM's implicit
    // empty default: an Apple consumer sends through URLSession and never fetches the SwiftNIO stack.
    .default(enabledTraits: []),
    .trait(
      name: "HTTPPortable",
      description: "Send through swifty-networking's AsyncHTTPClient transport on Linux and Android."
    ),
  ],
  dependencies: [
    // The trait of the same name is forwarded only while this package's own `HTTPPortable` trait is
    // enabled, so the AsyncHTTPClient and SwiftNIO packages behind it are resolved for no one else.
    .package(
      url: "https://github.com/KalebCooper/swifty-networking.git",
      from: "1.0.0",
      traits: [.trait(name: "HTTPPortable", condition: .when(traits: ["HTTPPortable"]))]
    )
  ],
  targets: [
    // `HTTPURLSession` compiles only on Apple platforms, and `HTTPPortable` is an empty module unless
    // its trait is enabled, so each edge is conditioned on the case where the module has content.
    .target(
      name: "SwiftNWS",
      dependencies: [
        .product(name: "HTTPCore", package: "swifty-networking"),
        .product(
          name: "HTTPPortable", package: "swifty-networking",
          condition: .when(traits: ["HTTPPortable"])),
        .product(
          name: "HTTPURLSession", package: "swifty-networking",
          condition: .when(platforms: [.iOS, .macCatalyst, .macOS, .tvOS, .visionOS, .watchOS])),
        "SwiftNWSModels",
      ],
      swiftSettings: swiftSettings
    ),
    .target(name: "SwiftNWSModels", swiftSettings: swiftSettings),
    .testTarget(
      name: "SwiftNWSModelsTests", dependencies: ["SwiftNWSModels"], swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "SwiftNWSTests", dependencies: ["SwiftNWS", "SwiftNWSModels"], swiftSettings: swiftSettings
    ),
  ],
  swiftLanguageModes: [.v6]
)

// Library code is nonisolated by default (the inverse of an app target's MainActor default), async
// entry points run on the caller's actor until they truly suspend, and every `unsafe` is spelled out.
var swiftSettings: [SwiftSetting] {
  [
    .defaultIsolation(nil),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .strictMemorySafety(),
  ]
}
