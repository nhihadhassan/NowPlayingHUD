// The entry point for this project's test suite. See `MiniTest.swift` for why this is a plain
// executable (`swift run NowPlayingHUDKitTests` / `make test`) rather than `swift test`.

let runner = TestRunner.shared
registerProgressEstimatorTests(on: runner)
registerPlaybackSnapshotDedupTests(on: runner)
registerProviderArbitrationTests(on: runner)
registerPreferencesStoreTests(on: runner)
await registerArtworkTests(on: runner)
registerScreenPositioningTests(on: runner)
registerScreenSelectionTests(on: runner)
registerHUDStateMachineTests(on: runner)
runner.summarizeAndExit()
