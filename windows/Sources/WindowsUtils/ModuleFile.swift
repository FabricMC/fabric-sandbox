import WinSDK

// Get the full path of the current process executable

public func getModuleFileName() throws -> File {
  var buffer = [WCHAR](repeating: 0, count: Int(MAX_PATH))
  let result = buffer.withUnsafeMutableBufferPointer { buffer in
    GetModuleFileNameW(nil, buffer.baseAddress, DWORD(buffer.count))
  }
  guard result != 0 else {
    throw Win32Error("GetModuleFileNameW")
  }

  return File(String(decodingCString: buffer, as: UTF16.self))
}
