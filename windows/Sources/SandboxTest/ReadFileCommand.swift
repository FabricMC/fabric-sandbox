import WinSDK
import WindowsUtils

class ReadFileCommand: Command {
  func execute(_ arguments: [String]) throws {
    let path = arguments.first!
    let file = CreateFileW(
      path.wide, GENERIC_READ, DWORD(FILE_SHARE_READ), nil, DWORD(OPEN_EXISTING),
      DWORD(FILE_ATTRIBUTE_NORMAL), nil)

    guard file != INVALID_HANDLE_VALUE else {
      if GetLastError() == ERROR_ACCESS_DENIED {
        print("Access is denied")
        return
      }

      throw Win32Error("CreateFileW")
    }
    defer { CloseHandle(file) }

    let size = GetFileSize(file, nil)
    guard size != INVALID_FILE_SIZE else {
      throw Win32Error("GetFileSize")
    }

    var buffer = [UInt8](repeating: 0, count: Int(size + 1))
    let result = ReadFile(file, &buffer, DWORD(size), nil, nil)
    guard result else {
      throw Win32Error("ReadFile")
    }

    let text = String(decodingCString: buffer, as: UTF8.self)
    print("File content: \(text)")
  }
}
