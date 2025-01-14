import WindowsUtils

class NamedPipeCommand: Command {
  func execute(_ arguments: [String]) throws {
    do {
      let name = arguments.first ?? "TestPipe"
      let pipeClient = try NamedPipeClient(pipeName: name)
      let _ = try pipeClient.send("Hello, World!")
      print("Sent message to named pipe")
    } catch {
      print("Error: \(error)")
    }
  }
}
