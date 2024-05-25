import WinSDK

// https://stackoverflow.com/questions/39138674/accessing-named-pipe-servers-from-within-ie-epm-bho
// Local System - full access
// Everyone - full access
// App packages - full access

/// A named pipe server can receive messages from a single client

/// A write only named pipe client
let bufferSize = DWORD(4096)
let securityDescriptor = "S:(ML;;NW;;;LW)D:(A;;FA;;;SY)(A;;FA;;;WD)(A;;FA;;;AC)"
open class NamedPipeServer: Thread {
  let pipe: HANDLE
  public let path: String

  public init(pipeName: String) throws {
    // Create a security descriptor
    var security: PSECURITY_DESCRIPTOR?
    let result = ConvertStringSecurityDescriptorToSecurityDescriptorW(
      securityDescriptor.wide,
      DWORD(1),
      &security,
      nil
    )
    guard result else {
      throw Win32Error("ConvertStringSecurityDescriptorToSecurityDescriptorW")
    }

    var securityAttributesValue = SECURITY_ATTRIBUTES(
      nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size), lpSecurityDescriptor: security,
      bInheritHandle: false)

    let pipe = withUnsafeMutablePointer(to: &securityAttributesValue) {
      CreateNamedPipeW(
        pipeName.wide,
        DWORD(PIPE_ACCESS_DUPLEX),
        DWORD(PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT),
        DWORD(1),  // Only one client
        bufferSize,
        bufferSize,
        DWORD(0),
        $0
      )
    }
    guard pipe != INVALID_HANDLE_VALUE, let pipe = pipe else {
      throw Win32Error("CreateNamedPipeW")
    }
    self.pipe = pipe
    self.path = pipeName

    try super.init()

    // Start the thread to wait for clients
    start()
  }

  deinit {
    CloseHandle(pipe)
  }

  open override func run() {
    // Wait for a client to connect
    let connected = ConnectNamedPipe(pipe, nil)
    guard connected || GetLastError() == DWORD(ERROR_PIPE_CONNECTED) else {
      return
    }

    // Read the messages
    while true {
      var message = [UInt16](repeating: 0, count: Int(bufferSize) / MemoryLayout<WCHAR>.size)
      var bytesRead: DWORD = 0
      let read = ReadFile(pipe, &message, bufferSize - 1, &bytesRead, nil)
      guard read else {
        break
      }

      if onMessage(message) {
        break
      }
    }

    // Disconnect the client
    DisconnectNamedPipe(pipe)
  }

  // Receives a message from the client and returns whether the server should stop
  open func onMessage(_ message: [UInt16]) -> Bool {
    return false
  }
}
public class NamedPipeClient {
  let pipe: HANDLE

  public init(pipeName: String) throws {
    let pipe = CreateFileW(
      pipeName.wide,
      DWORD(GENERIC_WRITE),
      DWORD(0),
      nil,
      DWORD(OPEN_EXISTING),
      DWORD(0),
      nil
    )
    guard pipe != INVALID_HANDLE_VALUE, let pipe = pipe else {
      throw Win32Error("CreateFileW")
    }

    // Change to message mode
    var mode = DWORD(PIPE_READMODE_MESSAGE)
    let result = SetNamedPipeHandleState(pipe, &mode, nil, nil)
    guard result else {
      CloseHandle(pipe)
      throw Win32Error("SetNamedPipeHandleState")
    }

    self.pipe = pipe
  }

  deinit {
    CloseHandle(pipe)
  }

  public func sendBytes(_ bytes: [UInt16]) throws {
    var bytesWritten = DWORD(0)
    let write = WriteFile(
      pipe, bytes, DWORD(bytes.count * MemoryLayout<UInt16>.size), &bytesWritten, nil)
    guard write else {
      throw Win32Error("WriteFile")
    }
  }

  public func send(_ text: String) throws {
    let message = text.wide
    var bytesWritten = DWORD(0)
    let write = WriteFile(
      pipe, message, DWORD(message.count * MemoryLayout<WCHAR>.size), &bytesWritten, nil)
    guard write else {
      throw Win32Error("WriteFile")
    }
  }
}
