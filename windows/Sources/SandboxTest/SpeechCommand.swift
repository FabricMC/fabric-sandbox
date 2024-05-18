import WinSDK
import WindowsUtils
import WinSDKExtras

// Use the win32 Speech API to convert text to speech
class SpeechCommand: Command {
  private static let SPF_ASYNC = DWORD(1)
  private static let SPF_IS_NOT_XML = DWORD(1 << 4)

  func execute(_ arguments: [String]) throws {
    let _ = Com()
    let flags: DWORD = SpeechCommand.SPF_ASYNC | SpeechCommand.SPF_IS_NOT_XML
    var text = "Hello Fabric, Sandbox.".wide
    // let result = SAPI_SPEAK("Hello Fabric, Sandbox.".wide, flags)
    // guard result == S_OK else {
    //   print("Failed to speak")
    //   throw Win32Error("Failed to speak", result: result)
    // }

    Sleep(1500)

    print("Spoke")
    fflush(__acrt_iob_func(1))
  }
}