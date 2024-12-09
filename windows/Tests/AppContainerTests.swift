import Sandbox
import Testing
import WinSDK

@testable import FabricSandbox

@Suite(.serialized) struct AppContainerTests {
  @Test func testCreateAppContainerNoCapabilities() throws {
    let _ = try AppContainer.create(
      name: "TestContainer", description: "Test Container", capabilities: [])
  }

  @Test func testCreateAppContainerWithWellKnownCapabilities() throws {
    let _ = try AppContainer.create(
      name: "TestContainer", description: "Test Container",
      capabilities: [
        .wellKnown(WinCapabilityInternetClientSid),
        .wellKnown(WinCapabilityInternetClientServerSid),
        .wellKnown(WinCapabilityPrivateNetworkClientServerSid),
      ])
  }

  @Test func testCreateAppContainerWithCustomCapabilities() throws {
    let _ = try AppContainer.create(
      name: "TestContainer", description: "Test Container",
      capabilities: [
        .custom("inputForegroundObservation"),
        .custom("inputInjection"),
        .custom("inputInjectionBrokered"),
        .custom("inputObservation"),
        .custom("inputSettings"),
        .custom("inputSuppression"),
      ])
  }

  @Test func testAppContainerCreate() throws {
    let tempDir = try createTempDir()
    defer {
      try! tempDir.delete()
    }

    let container = try AppContainer.create(
      name: "TestContainer", description: "Test Container", capabilities: [])
    print("SID: '\(container.sid)'")

    try grantAccess(tempDir, appContainer: container, accessPermissions: [.genericAll])
  }
}
