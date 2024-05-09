import Shared
import WinSDK
import WindowsUtils
import WinSDKExtras

// A named pipe server that listens for messages from the sandbox
// and performs the requested privileged operations

public class SandboxNamedPipeServer: NamedPipeServer {
  var com: Com? = nil

  public override init(pipeName: String) throws {
    try super.init(pipeName: pipeName)
  }

  deinit {
    com = nil
  }

  public override func onMessage(_ data: [UInt16]) -> Bool {
    let message = PipeMessages.fromBytes(data)
    guard let message = message else {
      print("Failed to parse message")
      return true
    }

    switch message {
    case .exit:
      return true
    case .clipCursor(let rect):
      if rect.left < 0 && rect.top < 0 && rect.right < 0 && rect.bottom < 0 {
        // Unclip the cursor when the rect is all 0s
        ClipCursor(nil)
      } else {
        let rect = RECT(
          left: LONG(rect.left), top: LONG(rect.top), right: LONG(rect.right),
          bottom: LONG(rect.bottom))
        let _ = withUnsafePointer(to: rect) {
          ClipCursor($0)
        }
      }
    case .setCursorPos(let pos):
      SetCursorPos(pos.x, pos.y)
    case .speak(let speak):
      if com == nil {
        // Initialize COM for the current thread
        com = Com()
      }
      SAPI_SPEAK(speak.text.wide, speak.flags)
    }
    return false
  }
}
