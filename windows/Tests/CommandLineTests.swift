import Testing
import WindowsUtils

@testable import FabricSandbox

struct CommandLineTests {
  @Test func testParseCommandLine() throws {
    let commandLine = try getCommandLine()
    print("Command Line: \(commandLine)")
  }
}
