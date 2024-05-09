import WinSDK
import WindowsUtils
import SandboxTestCpp

// Use the win32 Speech API to convert text to speech
class SpeechCommand: Command {
  func execute(_ arguments: [String]) throws {
    let _ = Com()

    print("Speaking...")
    let result: HRESULT = sapi_speak("Hello Fabric Sandbox.")
    guard result == S_OK else {
      print("Failed to speak")
      throw Win32Error("Failed to speak", result: result)
    }

    // Sleep for a bit to allow the speech to finish
    Sleep(1500)

    print("Spoke")
    fflush(__acrt_iob_func(1))
  }
}