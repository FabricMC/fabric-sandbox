import WinSDK
import WindowsUtils
import WinSDKExtras
import CxxStdlib

// Use the win32 Speech API to convert text to speech
class SpeechCommand: Command {
  private static let SPF_ASYNC = DWORD(1)
  private static let SPF_IS_NOT_XML = DWORD(1 << 4)

  func execute(_ arguments: [String]) throws {
    CoInitializeEx(nil, 0)
    defer {
      CoUninitialize()
    }

    var speak = SpeakApi()
    let flags: DWORD = SpeechCommand.SPF_ASYNC | SpeechCommand.SPF_IS_NOT_XML
    let result = speak.Speak(std.string("Hello Fabric, Sandbox. This is a long message that will get cut off"), flags)
    guard result == S_OK else {
       throw Win32Error("Failed to speak", result: result)
    }

    Sleep(2000)

    speak.Skip()

    print("Spoke")
  }
}