import WinSDK
import WindowsUtils

@main
class SandboxTest {
  static func main() throws {
    let commands: [String: Command] = [
      "smoke": SmokeCommand(),
      "readFile": ReadFileCommand(),
      "registry": RegistryCommand(),
      "namedPipe": NamedPipeCommand(),
      "nameMax": NameMaxCommand(),
      "mouseMovements": MouseMovementsCommand(),
      "speech": SpeechCommand(),
    ]

    if CommandLine.arguments.count < 2 {
      throw SandboxTestError("No arguments")
    }

    let result = LoadLibraryW("Hook.dll".wide)
    guard result != nil else {
      throw SandboxTestError("Failed to load Hook.dll")
    }

    let command = CommandLine.arguments[1]
    let remainingArguments = Array(CommandLine.arguments.dropFirst(2))

    if let command = commands[command] {
      try command.execute(remainingArguments)
    } else {
      throw SandboxTestError("Unknown command")
    }
  }

  struct SandboxTestError: Error {
    let message: String

    init(_ message: String) {
      self.message = message
    }
  }
}
