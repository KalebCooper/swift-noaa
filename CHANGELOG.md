# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- `HTTPPortable`, an off-by-default trait that forwards to swifty-networking's trait of the same
  name, so `SwiftNWS` can send through AsyncHTTPClient on Linux and Android.
- `NWSConfiguration` in `SwiftNWS`, holding the `User-Agent` every request to the API must carry.
- `MediaType` in `SwiftNWSModels`, a media type the API answers with, and `MediaType.geoJSON`.
- The `SwiftNWSModels` and `SwiftNWS` products.
