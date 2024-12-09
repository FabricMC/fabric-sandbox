import Shared
import WinSDK
import WindowsUtils

nonisolated(unsafe) private var pipeClient: NamedPipeClient? = nil

public func processAttach() {
  // TODO fix me
  //guard isSandboxed() else {
  //      fatalError("Process is not sandboxed")
  //      return
  //}

  do {
    let pipeName = try getJvmProp("sandbox.namedPipe")
    guard let pipeName = pipeName else {
      #if RELEASE
        fatalError("No named pipe path specified in JVM properties")
      #endif
      return
    }

    pipeClient = try NamedPipeClient(pipeName: pipeName)
  } catch {
    fatalError("Failed to create pipe client \(error)")
  }
}

public func clipCursor(left: Int32, top: Int32, right: Int32, bottom: Int32) {
  sendMessage(.clipCursor(Rect(left: left, top: top, right: right, bottom: bottom)))
}

public func setCursorPos(x: Int32, y: Int32) {
  sendMessage(.setCursorPos(Pos(x: x, y: y)))
}

public func speak(text: String, flags: UInt32) {
  sendMessage(.speak(Speak(text: text, flags: flags)))
}

public func speakSkip() {
  sendMessage(.speakSkip)
}

public func processDetach() {
  // Disconnect and close the pipe client
  pipeClient = nil
}

func getJvmProp(_ propName: String) throws -> String? {
  let prop = "-D\(propName)="
  for arg in try getCommandLine() {
    if arg.starts(with: prop) {
      return String(arg.dropFirst(prop.count))
    }
  }
  return nil
}

func sendMessage(_ message: PipeMessages) {
  guard let pipeClient = pipeClient else {
    #if RELEASE
      fatalError("Named pipe client is not initialized")
    #endif
    return
  }

  do {
    try pipeClient.sendBytes(message.toBytes())
  } catch {
    fatalError("Failed to send pipe message")
  }
}

func isSandboxed() -> Bool {
  var processHandle: HANDLE? = nil
  var result = OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &processHandle)
  guard result, processHandle != INVALID_HANDLE_VALUE else {
    fatalWin32Error("OpenProcessToken")
    return false
  }

  var isAppContainer = false
  var returnLength: DWORD = 0
  result = GetTokenInformation(
    &processHandle, TokenIsAppContainer, &isAppContainer, DWORD(MemoryLayout<Bool>.size),
    &returnLength)
  guard result else {
    fatalWin32Error("GetTokenInformation")
    return false
  }

  return isAppContainer
}

func fatalWin32Error(_ message: String) {
  fatalError("\(Win32Error(message))")
}

func fatalError(_ message: String) {
  MessageBoxW(nil, message.wide, "Fatal Sandbox Error".wide, UINT(MB_ICONERROR | MB_OK))
  print(message)
  TerminateProcess(GetCurrentProcess(), UINT(100))
}
