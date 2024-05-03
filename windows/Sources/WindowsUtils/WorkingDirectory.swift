import WinSDK

public func getWorkingDirectory() throws -> File {
  let buffer: UnsafeMutablePointer<WCHAR> = .allocate(capacity: Int(MAX_PATH))
  defer { buffer.deallocate() }
  let dwResult = GetCurrentDirectoryW(DWORD(MAX_PATH), buffer)
  guard dwResult > 0 else {
    throw Win32Error("GetCurrentDirectoryW")
  }
  return File(String(decodingCString: buffer, as: UTF16.self))
}
