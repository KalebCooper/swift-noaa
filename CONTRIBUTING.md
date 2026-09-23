# Contributing to swift-noaa

Contributions are welcome. Open an issue to discuss an addition before investing in a large pull
request.

## Getting started

1. Fork and clone the repository.
2. Open the package directory in Xcode 26 or later.
3. Build and test with Xcode's generated `swift-noaa-Package` scheme (⌘U), or run `swift test`.

## Before you open a pull request

Run these from the package directory. Each must pass.

| Check | Command |
|---|---|
| Tests | the `swift-noaa-Package` scheme in Xcode, or `swift test` |
| Format | `swift format lint --strict --recursive Sources Tests`, with zero findings |
| Repository invariants | `bash Scripts/verify.sh`, which also runs the format lint |
| Linux, trait on and off | `bash Scripts/linux-test.sh` (needs Docker) |

`swift format --in-place --recursive Sources Tests` fixes most format findings. After changing
`Scripts/verify.sh`, `bash Scripts/verify.sh --self-test` proves each check still trips on a planted
violation, and a new check ships with one.

Target `main`, keep one concern per pull request, and record any change to the public surface under
**Unreleased** in `CHANGELOG.md`.

## Guidelines

- **Layers:** `SwiftNWSModels` depends on nothing. It never imports swifty-networking, `URLSession`,
  or any transport type; if a type needs one to exist, it belongs in `SwiftNWS`. `SwiftNWS` adds
  behavior, never models.
- **Three levels:** a new operation is an everyday `NWSClient` method, an equivalent
  `WeatherRequest` factory, and the `Endpoint` values it sends, sharing one executor.
- **Provider data:** keep what the service sends. Unknown codes stay in `rawValue`, `null` stays
  `nil`, and nothing is converted, sorted, filtered, or given a fallback the service does not promise.
- **Portability:** `SwiftNWSModels` imports Foundation only as the fallback to `FoundationEssentials`.
  Darwin-only code sits inside `#if canImport(Darwin)`, and code that uses the portable transport sits
  inside `#if HTTPPortable`.
- **Concurrency:** no actors on the client; shared state is `Mutex` or `Atomic`. Errors are typed and
  mapped at each layer. Inject a `Clock`; never sleep or read the wall clock.
- **Tests:** Swift Testing only, and never against the live API. Record a response once into
  `Sources/SwiftNWSTestSupport/Fixtures/` with the User-Agent
  `(swift-noaa, https://github.com/KalebCooper/swift-noaa)` and add a `Fixture` case naming the path
  you recorded. Every `@Suite` carries `.timeLimit(.minutes(suiteTimeLimitMinutes))`, so a test that
  stops making progress fails its suite instead of holding the run open.
- **Style:** declarations are ordered alphabetically within their groupings unless an inline comment
  says why not. No force unwraps, `try!`, or `as!` in `Sources/`.
- **Scope:** no macros, no interceptor or middleware pipelines, no speculative API.

## Documentation

Every public symbol needs a DocC comment: a one-sentence summary, what it does and does not
guarantee, and the specific `NWSError` cases it throws. A new feature updates the matching DocC
article in each product, the README, and the changelog in the same pull request.

To build the documentation site locally, build `SwiftNWS` for an iOS simulator, then run
`bash Scripts/build-docs.sh /path/to/Debug-iphonesimulator /tmp/swift-noaa-docs` with a new output
directory. It extracts only the two products' public symbols, builds `SwiftNWSModels` first and
`SwiftNWS` against it with warnings treated as errors, and writes the static site to the output
directory's `site` folder.

## Continuous integration

CI runs the tests on Linux (trait on, then the default trait set), an Android emulator, and an iOS
simulator, lints the format, builds the demo in Release configuration, and builds the documentation
on pull requests. The documentation site publishes only from `main`.

## Releases

Before tagging a release, run every check above, build the documentation with `Scripts/build-docs.sh`,
and build and run the demo with the package closed in Xcode. Tag only after every CI lane passes on
the release commit; a local pass does not establish hosted or Android success.

## Reporting issues

Include the method or endpoint you called, what you expected, what happened, and a minimal
reproduction where possible. If the service answered with problem details, include them.
