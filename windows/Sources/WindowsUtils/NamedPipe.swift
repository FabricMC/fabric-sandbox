import WinSDK

let bufferSize = DWORD(4096)

protocol NamedPipe {
  var pipe: HANDLE { get }
  var path: String { get }
}

open class NamedPipeServer: Thread, NamedPipe {
  public let pipe: HANDLE
  public let path: String

  public init(pipeName: String, allowedTrustees: [Trustee]) throws {
    let acl = try createACLWithTrustees(allowedTrustees)
    defer { LocalFree(acl) }

    var securityDescriptor = SECURITY_DESCRIPTOR()

    var result = InitializeSecurityDescriptor(&securityDescriptor, DWORD(SECURITY_DESCRIPTOR_REVISION))
    guard result else {
      throw Win32Error("InitializeSecurityDescriptor")
    }

    result = SetSecurityDescriptorDacl(&securityDescriptor, true, acl, false)
    guard result else {
      throw Win32Error("SetSecurityDescriptorDacl")
    }

    let relativeDescriptor = try createSelfRelativeSecurityDescriptor(&securityDescriptor)
    defer { relativeDescriptor.deallocate() }

    var securityAttributesValue = SECURITY_ATTRIBUTES(
      nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
      lpSecurityDescriptor: relativeDescriptor,
      bInheritHandle: false)

    let pipe = CreateNamedPipeW(
      pipeName.wide,
      DWORD(PIPE_ACCESS_DUPLEX),
      DWORD(PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT),
      DWORD(1),  // Only one client
      bufferSize,
      bufferSize,
      DWORD(0),
      &securityAttributesValue
    )
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
      let message = try? readBytes(pipe: pipe)
      guard let message = message else {
        // The client disconnected
        break
      }

      guard let response = onMessage(message) else {
        // The server will disconnect from the client
        break
      }

      do {
        try writeBytes(pipe: pipe, data: response)
      } catch {
        // The client disconnected
        break
      }
    }

    // Disconnect the client
    DisconnectNamedPipe(pipe)
  }

  // Receives a message from the client and returns a response
  // If the response is nil, the server will disconnect from the client
  open func onMessage(_ message: [UInt16]) -> [UInt16]? {
    return []
  }
}

public class NamedPipeClient: NamedPipe {
  public let pipe: HANDLE
  public let path: String

  private let mutex = Mutex()

  public init(pipeName: String, desiredAccess: DWORD = DWORD(GENERIC_WRITE) | DWORD(GENERIC_READ), mode: DWORD? = DWORD(PIPE_READMODE_MESSAGE)) throws {
    let pipe = CreateFileW(
      pipeName.wide,
      desiredAccess,
      0,
      nil,
      DWORD(OPEN_EXISTING),
      0,
      nil
    )
    guard pipe != INVALID_HANDLE_VALUE, let pipe = pipe else {
      throw Win32Error("CreateFileW")
    }

    if var mode = mode  {
      let result = SetNamedPipeHandleState(pipe, &mode, nil, nil)
      guard result else {
        CloseHandle(pipe)
        throw Win32Error("SetNamedPipeHandleState")
      }
    }

    self.pipe = pipe
    self.path = pipeName
  }

  deinit {
    CloseHandle(pipe)
  }

  public func sendBytes(_ bytes: [UInt16]) throws -> [UInt16] {
    // Only allow one thread to write at a time
    try mutex.wait()
    defer { mutex.release() }

    try writeBytes(pipe: pipe, data: bytes)
    return try readBytes(pipe: pipe)
  }

  public func send(_ text: String) throws -> String {
    let response = try sendBytes(text.wide)
    return String(decodingCString: response, as: UTF16.self)
  }
}

fileprivate func writeBytes(pipe: HANDLE, data: [UInt16]) throws {
  guard data.count > 0 else {
    throw Win32Error("Message is empty", errorCode: DWORD(ERROR_INVALID_PARAMETER))
  }

  guard data.count < bufferSize else {
    throw Win32Error("Message is too large to write", errorCode: DWORD(ERROR_INVALID_PARAMETER))
  }

  var bytesWritten = DWORD(0)
  let write = WriteFile(
    pipe, data, DWORD(data.count * MemoryLayout<UInt16>.size), &bytesWritten, nil)
  guard write else {
    throw Win32Error("WriteFile")
  }

  guard FlushFileBuffers(pipe) else {
    throw Win32Error("FlushFileBuffers")
  }
}

fileprivate func readBytes(pipe: HANDLE) throws -> [UInt16] {
  var message = [UInt16](repeating: 0, count: Int(bufferSize) / MemoryLayout<WCHAR>.size)
  var bytesRead: DWORD = 0
  let read = ReadFile(pipe, &message, bufferSize - 1, &bytesRead, nil)
  guard read else {
    throw Win32Error("ReadFile")
  }

  return message
}