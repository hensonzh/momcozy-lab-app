import XCTest

final class RunnerConfigurationTests: XCTestCase {
  func testRunnerUsesMomCozyBundleIdentifier() {
    XCTAssertTrue(
      Bundle.main.bundleIdentifier?.hasPrefix("com.momcozymai.app.flutterpoc") == true
    )
  }
}
