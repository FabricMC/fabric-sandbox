import WinSDK
import WindowsUtils
import SandboxTestCpp

// Use the win32 Speech API to convert text to speech
class SpeechCommand: Command {
  func execute(_ arguments: [String]) throws {
    CoInitializeEx(nil, 0)
    defer {
      CoUninitialize()
    }

    let result: HRESULT = sapi_speak("Hello, Fabric Sandbox.")
    guard result == S_OK else {
      throw Win32Error("Failed to speak", result: result)
    }

    print("Spoke")
  }
}