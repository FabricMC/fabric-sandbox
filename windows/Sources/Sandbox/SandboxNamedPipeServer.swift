import Shared
import WinSDK
import WindowsUtils
import WinSDKExtras
import CxxStdlib

// A named pipe server that listens for messages from the sandbox
// and performs the requested privileged operations

public class SandboxNamedPipeServer: NamedPipeServer {
  private var speech: Speech? = nil

  public override init(pipeName: String, allowedTrustees: [Trustee]) throws {
    try super.init(pipeName: pipeName, allowedTrustees: allowedTrustees + [TokenUserTrustee()])
  }

  public override func onMessage(_ data: [UInt16]) -> [UInt16]? {
    let message = PipeMessages.fromBytes(data)
    guard let message = message else {
      print("Failed to parse message")
      return nil
    }

    switch message {
    case .exit:
      return nil
    case .clipCursor(let rect):
      if rect.left < 0 && rect.top < 0 && rect.right < 0 && rect.bottom < 0 {
        // Unclip the cursor when the rect is all 0s
        ClipCursor(nil)
      } else {
        var rect = RECT(
          left: LONG(rect.left), top: LONG(rect.top), right: LONG(rect.right),
          bottom: LONG(rect.bottom))
        let _ = ClipCursor(&rect)
      }
    case .setCursorPos(let pos):
      SetCursorPos(pos.x, pos.y)
    case .speak(let speak):
      if speech == nil {
        speech = Speech()
      }
      speech!.Speak(speak.text, speak.flags)
    case .speakSkip:
      if speech == nil {
        speech = Speech()
      }
      speech!.Skip()
    }

    return [ 0 ]
  }
}

private class Speech {
  var speakApi: SpeakApi

  init() {
    CoInitializeEx(nil, 0)
    speakApi = SpeakApi()
  }

  deinit {
    CoUninitialize()
  }

  func Speak(_ text: String, _ flags: UInt32) {
    speakApi.Speak(std.string(text), flags)
  }

  func Skip() {
    speakApi.Skip()
  }
}