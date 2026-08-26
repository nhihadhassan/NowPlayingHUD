import Foundation

/// A tiny, dependency-free test harness used in place of XCTest/Swift Testing.
///
/// This machine has Xcode's Command Line Tools only (no full Xcode.app): there is no
/// `XCTest.framework`, and — verified directly, with a deliberately-failing assertion — `swift
/// test` on this toolchain compiles and links the Swift Testing-based test bundle successfully
/// but never actually executes it (`swiftpm-testing-helper` dlopens the bundle and exits 0
/// having run nothing, on both passing and deliberately-failing suites alike). Rather than ship
/// tests that merely *compile* without ever being confirmed to run, this project's tests are a
/// small executable (`swift run NowPlayingHUDKitTests` / `make test`) built entirely from
/// Foundation, so `swift run`'s ordinary process-exit semantics are the pass/fail signal — no
/// bundle loading, no toolchain-specific test-runner plumbing.
struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// Throws if `condition` is false, to be used inside a `test(...)` block.
func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = "expectation failed",
    file: StaticString = #file, line: UInt = #line
) throws {
    if !condition() {
        throw TestFailure(message: "\(message()) (\(file):\(line))")
    }
}

final class TestRunner {
    static let shared = TestRunner()
    private init() {}

    private var totalRun = 0
    private var totalFailed = 0
    private var failureDetails: [String] = []

    func suite(_ name: String, _ body: () -> Void) {
        print("\n\u{2500}\u{2500} \(name) \u{2500}\u{2500}")
        body()
    }

    func test(_ name: String, _ body: () throws -> Void) {
        totalRun += 1
        do {
            try body()
            print("  \u{2705} \(name)")
        } catch {
            totalFailed += 1
            let description = (error as? TestFailure)?.description ?? "\(error)"
            print("  \u{274C} \(name): \(description)")
            failureDetails.append("\(name): \(description)")
        }
    }

    /// Async variant, for exercising actors (`ArtworkCache`, `ArtworkService`).
    func testAsync(_ name: String, _ body: () async throws -> Void) async {
        totalRun += 1
        do {
            try await body()
            print("  \u{2705} \(name)")
        } catch {
            totalFailed += 1
            let description = (error as? TestFailure)?.description ?? "\(error)"
            print("  \u{274C} \(name): \(description)")
            failureDetails.append("\(name): \(description)")
        }
    }

    /// Prints a summary and exits the process with a status reflecting pass/fail, mirroring
    /// `swift test`'s own exit-code convention (0 = all passed).
    func summarizeAndExit() -> Never {
        print("\n\(totalRun - totalFailed)/\(totalRun) tests passed")
        if !failureDetails.isEmpty {
            print("\nFailures:")
            for detail in failureDetails { print("  - \(detail)") }
        }
        exit(totalFailed == 0 ? 0 : 1)
    }
}
