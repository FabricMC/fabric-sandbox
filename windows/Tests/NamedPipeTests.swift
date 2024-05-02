@_spi(Experimental) import Testing
import WinSDK
import WindowsUtils

@Suite struct NamedPipeTests {
  @Test func namedPipe() throws {
    let server = try TestNamedPipeServer()
    let client = try NamedPipeClient(pipeName: server.pipeName)

    let message = "Hello, World!"
    try client.send(message)

    server.waitForNextMessage()

    let receivedMessage = server.lastMessage ?? ""
    #expect(receivedMessage == message)
    try client.send("exit")
  }
}

class TestNamedPipeServer: NamedPipeServer {
  var lastMessage: String? = nil
  var onMessageEvent: HANDLE
  let pipeName: String

  init() throws {
    onMessageEvent = CreateEventW(nil, false, false, nil)
    self.pipeName = "\\\\.\\pipe\\FabricSandboxTest" + randomString(length: 10)
    try super.init(pipeName: self.pipeName)
  }

  override func onMessage(_ message: String) -> Bool {
    if message == "exit" {
      return true
    }

    self.lastMessage = message
    SetEvent(onMessageEvent)

    return false
  }

  func waitForNextMessage() {
    let result = WaitForSingleObject(onMessageEvent, 1000)
    #expect(result == WAIT_OBJECT_0)
  }
}
