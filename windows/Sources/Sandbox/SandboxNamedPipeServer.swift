import Shared
import WinSDK
import WindowsUtils
import WinSDKExtras
import CxxStdlib

// A named pipe server that listens for messages from the sandbox
// and performs the requested privileged operations

public class SandboxNamedPipeServer: NamedPipeServer {
  private var speakService: SpeakService? = nil

  public override init(pipeName: String) throws {
    try super.init(pipeName: pipeName)
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
      if speakService == nil {
        speakService = SpeakService()
      }
      speakService!.Speak(speak.text, speak.flags)
    case .speakSkip:
      if speakService == nil {
        speakService = SpeakService()
      }
      speakService!.Skip()
    }
    return false
  }
}

private class SpeakService {
  let com: Com
  var speakApi: SpeakApi

  init() {
    com = Com()
    speakApi = SpeakApi()
  }

  func Speak(_ text: String, _ flags: UInt32) {
    speakApi.Speak(std.wstring(text.wide), flags)
  }

  func Skip() {
    speakApi.Skip()
  }
}