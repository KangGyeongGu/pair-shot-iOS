import Foundation

/// Audit-D — single source for "where is the repo root from a test?".
///
/// Background: Audit-C tests (``LocalizationCoverageTests`` and
/// ``ViewLineCountAuditTests``) walked up from
/// `Bundle(for: …).bundleURL` looking for `PairShot/PairShot/PairShotApp.swift`.
/// On the Simulator the test bundle lives deep inside
/// `~/Library/Developer/CoreSimulator/.../Bundle/Application/<UUID>/PairShot.app/PluginsAttribute/PairShotTests.xctest/`,
/// nowhere near the repo root, so the walk-up never matched and both
/// tests `XCTSkip`'d themselves. They effectively never ran.
///
/// Fix: Swift's `#filePath` literal expands at compile time to the
/// absolute path of the source file containing it. For this file that's
/// `<repo>/PairShot/PairShotTests/TestRepoLocator.swift` — strip the two
/// trailing path components and we have the repo root, regardless of
/// where the test bundle ended up at runtime.
///
/// The cached `repoRoot` is computed once per process so directory walks
/// are cheap.
enum TestRepoLocator {
    /// `<repo>` — the directory that contains the `PairShot/` Xcode
    /// project folder and `docs/`. Returns `nil` only when the source
    /// file was moved out of `PairShot/PairShotTests/` without updating
    /// this helper (defensive — should never happen in practice).
    static let repoRoot: URL? = {
        // `#filePath` resolves to:
        //   <repo>/PairShot/PairShotTests/TestRepoLocator.swift
        // We need to drop:
        //   - the file name              -> <repo>/PairShot/PairShotTests
        //   - the PairShotTests segment  -> <repo>/PairShot
        //   - the PairShot segment       -> <repo>
        let fileURL = URL(fileURLWithPath: #filePath)
        let candidate = fileURL
            .deletingLastPathComponent() // .../PairShotTests
            .deletingLastPathComponent() // .../PairShot
            .deletingLastPathComponent() // <repo>

        // Sanity check the result actually contains the project — if a
        // future refactor moves this file the helper should fail loudly
        // rather than silently returning a wrong path.
        let probe = candidate
            .appendingPathComponent("PairShot")
            .appendingPathComponent("PairShot")
            .appendingPathComponent("PairShotApp.swift")
        guard FileManager.default.fileExists(atPath: probe.path) else {
            return nil
        }
        return candidate
    }()

    /// Resolve a path relative to the repo root.
    /// Returns `nil` when the repo root itself can't be located (i.e.
    /// this helper was moved). Callers may assert non-nil with
    /// `XCTUnwrap` — the resolution is deterministic at compile time.
    static func url(forRelativePath path: String) -> URL? {
        repoRoot?.appendingPathComponent(path)
    }
}
