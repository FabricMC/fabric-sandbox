import WinSDK
import WinSDKExtras

public struct Win32Error: Error {
  let messsage: String
  let errorCode: DWORD
  let errorMessage: String?

  public init(_ message: String, errorCode: DWORD = GetLastError()) {
    self.messsage = message
    self.errorCode = errorCode
    self.errorMessage = toErrorMessage(errorCode)
  }

  public init(_ message: String, result: HRESULT) {
    self.init(message, errorCode: Win32FromHResult(result))
  }

  var errorDescription: String? {
    return errorMessage
  }
}

internal func toErrorMessage(_ errorCode: DWORD) -> String? {
  var buffer: UnsafeMutablePointer<WCHAR>? = nil

  let dwResult: DWORD = withUnsafeMutablePointer(to: &buffer) {
    $0.withMemoryRebound(to: WCHAR.self, capacity: 2) {
      FormatMessageW(
        DWORD(
          FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM
            | FORMAT_MESSAGE_IGNORE_INSERTS),
        nil, errorCode, _MAKELANGID(WORD(LANG_NEUTRAL), WORD(SUBLANG_DEFAULT)), $0, 0, nil)
    }
  }

  guard dwResult > 0, let message = buffer else {
    return nil
  }

  defer { LocalFree(buffer) }

  return String(
    String(decodingCString: message, as: UTF16.self)
      .dropLast(1)  // Remove trailing \r\n
  )
}
