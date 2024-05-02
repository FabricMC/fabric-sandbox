import WinSDK

public func getWorkingDirectory() throws -> File {
  var buffer: UnsafeMutablePointer<WCHAR> = .allocate(capacity: Int(MAX_PATH))
  let dwResult: DWORD = withUnsafeMutablePointer(to: &buffer) {
    GetCurrentDirectoryW(DWORD(MAX_PATH), $0.pointee)
  }
  guard dwResult > 0 else {
    throw Win32Error("GetCurrentDirectoryW")
  }
  return File(String(decodingCString: buffer, as: UTF16.self))
}
