import Testing

/// Sanity-check entry into the Swift Testing harness so the framework
/// is wired up; the real coverage lives in the per-feature `XCTestCase`
/// files under `SnapperTests/Services`, `SnapperTests/ViewModels`, etc.
struct SnapperTests {

    @Test func example() async throws {
        #expect(Bool(true))
    }

}
