import Sandbox
@_spi(Experimental) import Testing
import WinSDK
import WindowsUtils

@testable import FabricSandbox

/// Run SandboxTest.exe with the given options in a sandbox, returning the exit code and command line output

@Suite(.serial) struct IntergrationTests {
  @Test func testRunSmoke() throws {
    let (exitCode, output) = try runIntergration(["smoke"])
    #expect(exitCode == 0)
    #expect(output == "Smoke test")
  }

  // Disabled as its flaky @Test
  func testRunSmokeLpac() throws {
    let (exitCode, output) = try runIntergration(["smoke"], lpac: true)
    #expect(exitCode == 0)
    #expect(output == "Smoke test")
  }

  @Test func testReadFileNoAccess() throws {
    let tempDir = try createTempDir()
    defer {
      try! tempDir.delete()
    }

    let tempFile = tempDir.child("test.txt")
    try tempFile.writeString("Hello, World!")

    let (exitCode, output) = try runIntergration(["readFile", tempFile.path()])
    #expect(exitCode == 0)
    #expect(output.contains("Access is denied"))
  }

  @Test func testReadFileWithAccess() throws {
    let tempDir = try createTempDir()
    defer {
      try! tempDir.delete()
    }

    let tempFile = tempDir.child("test.txt")
    try tempFile.writeString("Hello, World!")

    let (exitCode, output) = try runIntergration(
      ["readFile", tempFile.path()],
      filePermissions: [
        FilePermission(path: tempFile, accessPermissions: [.genericRead])
      ])
    #expect(exitCode == 0)
    #expect(output.contains("Hello, World!"))
  }

  @Test func testRegistryCreate() throws {
    let (exitCode, output) = try runIntergration(["registry", "create"])
    #expect(exitCode == 0)
    #expect(output.contains("CreateKey test"))
    #expect(output.contains("Failed to create key"))
    #expect(output.contains("Access is denied"))
  }

  @Test func testRegistryWrite() throws {
    let (exitCode, output) = try runIntergration(["registry", "write"])
    #expect(exitCode == 0)
    #expect(output.contains("WriteKey test"))
    #expect(output.contains("Failed to write user key"))
    #expect(output.contains("Failed to write local machine key"))
  }

  @Test func namedPipe() throws {
    let server = try TestNamedPipeServer()
    let (exitCode, output) = try runIntergration(["namedPipe", server.pipeName], namedPipe: server)
    #expect(exitCode == 0)
    #expect(output.contains("Sent message to named pipe"))

    guard exitCode == 0 else {
      return
    }

    server.waitForNextMessage()

    let receivedMessage = server.lastMessage ?? ""
    #expect(receivedMessage == "Hello, World!")
  }

  @Test func testNamedMax() throws {
    let tempDir = try createTempDir()
    defer {
      try! tempDir.delete()
    }

    let driveLetter = MountedDisk.getNextDriveLetter(perfered: "S")
    guard let driveLetter = driveLetter else {
      throw SandboxError("No available drive letters")
    }

    let mountedDisk = try MountedDisk(path: tempDir, driveLetter: driveLetter)
    defer {
      try! mountedDisk.unmount()
    }

    let (exitCode, output) = try runIntergration(
      ["nameMax", "\(driveLetter):\\\\"],
      filePermissions: [
        FilePermission(
          path: mountedDisk.root(), accessPermissions: [.genericRead, .genericWrite])
      ])
    #expect(exitCode == 0)
    #expect(output.contains("Max component length: 255"))
  }

  @Test func mouseMovements() throws {
    let server = try SandboxNamedPipeServer(
      pipeName: "\\\\.\\pipe\\FabricSandbox" + randomString(length: 10))
    let (exitCode, _) = try runIntergration(
      ["mouseMovements", "-Dsandbox.namedPipe=\(server.path)"], namedPipe: server)
    #expect(exitCode == 0)
  }

  @Test func testSpeech() throws {
    let (exitCode, output) = try runIntergration(["speech"], capabilities: [.custom("backgroundMediaPlayback")])
    #expect(exitCode == 0)
    #expect(output == "Spoke")
  }
}
func runIntergration(
  _ args: [String], capabilities: [SidCapability] = [], filePermissions: [FilePermission] = [],
  lpac: Bool = false, namedPipe: NamedPipeServer? = nil
) throws -> (Int, String) {
  let workingDirectory = try getWorkingDirectory()
  let moduleDir = try getModuleFileName().parent()!
  let testExecutable = moduleDir.child("SandboxTest.exe")

  let container = try AppContainer.create(
    name: "Test Sandbox" + randomString(length: 10), description: "Test Sandbox",
    capabilities: capabilities, lpac: lpac)

  for filePermission in filePermissions {
    try grantAccess(
      filePermission.path, appContainer: container,
      accessPermissions: filePermission.accessPermissions)
  }

  let swiftBin = try findSwiftRuntimeDirectory()
  let swiftDlls = [
    "swiftWinSDK.dll",
    "swiftCore.dll",
    "swiftCRT.dll",
    "swiftSwiftOnoneSupport.dll",
  ]
  let swiftDllPaths = swiftDlls.map { swiftBin.child($0) }

  let hookDll = moduleDir.child("Hook.dll")

  // Grant access to the test executable, hook dll and swift binaries
  try grantAccess(
    testExecutable, appContainer: container,
    accessPermissions: [.genericRead, .genericExecute])
  try grantAccess(
    hookDll, appContainer: container,
    accessPermissions: [.genericRead, .genericExecute])

  for dll in swiftDllPaths {
    try grantAccess(
      dll, appContainer: container,
      accessPermissions: [.genericRead, .genericExecute])
  }

  if let namedPipe = namedPipe {
    try grantNamedPipeAccess(
      pipe: namedPipe, appContainer: container, accessPermissions: [.genericRead, .genericWrite])
  }

  let outputConsumer = TestOutputConsumer()
  let process = SandboxedProcess(
    application: testExecutable, commandLine: [testExecutable.path()] + args,
    workingDirectory: workingDirectory, container: container, outputConsumer: outputConsumer)
  let exitCode = try process.run()
  return (exitCode, outputConsumer.trimmed())
}
struct FilePermission {
  var path: File
  var accessPermissions: [AccessPermissions]
}
class TestOutputConsumer: OutputConsumer {
  var output = ""

  func consume(_ text: String) {
    output += text
  }

  func trimmed() -> String {
    // Remove leading and trailing whitespace without using Foundation
    return String(
      output
        .drop(while: { $0.isWhitespace })
        .reversed()
        .drop(while: { $0.isWhitespace })
        .reversed()
    )
  }
}
private func findSwiftRuntimeDirectory() throws -> File {
  // read path env var
  let path = try getEnvironmentVarible("PATH")!
  let paths = path.split(separator: ";")

  for path in paths {
    let dirPath = File(String(path))
    let dllPath = dirPath.child("swiftWinSDK.dll")
    if dllPath.exists() {
      return dirPath
    }
  }

  throw SandboxError("Swift runtime directory not found")
}
