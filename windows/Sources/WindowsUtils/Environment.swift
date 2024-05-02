import WinSDK

// Get the value of an environment variable

public func getEnvironmentVarible(_ name: String) throws -> String? {
  var size = GetEnvironmentVariableW(name.wide, nil, 0)
  guard size != 0 else {
    if GetLastError() == ERROR_ENVVAR_NOT_FOUND {
      return nil
    }
    throw Win32Error("GetEnvironmentVariableW")
  }

  var buffer = [WCHAR](repeating: 0, count: Int(size))

  size = buffer.withUnsafeMutableBufferPointer {
    GetEnvironmentVariableW(name.wide, $0.baseAddress, DWORD(size))
  }
  guard size != 0 else {
    throw Win32Error("GetEnvironmentVariableW")
  }

  return String(decodingCString: buffer, as: UTF16.self)
}
