import WinSDK
import WindowsUtils

private let useWorkaround = true

class NameMaxCommand: Command {
  func execute(_ arguments: [String]) throws {
    // GetVolumeInformationW is documented to be supported in UWP apps, but it doesn't work...
    let path = arguments.first!
    var maxComponentLength: DWORD = 0
    let result = GetVolumeInformationW(
      path.wide,
      nil,
      0,
      nil,
      &maxComponentLength,
      nil,
      nil,
      0)
    if result {
      print("Max component length: \(maxComponentLength)")
    } else {
      print(Win32Error("GetVolumeInformationW"))
    }

    // Make sure that the workaround works as well, even though it should have been applied already
    try executeWorkaround(arguments)
  }

  func executeWorkaround(_ arguments: [String]) throws {
    let tempFile = arguments.first! + "temp"
    let handle = CreateFileW(
      tempFile.wide,
      DWORD(GENERIC_READ),
      DWORD(FILE_SHARE_READ),
      nil,
      DWORD(OPEN_ALWAYS),
      DWORD(FILE_ATTRIBUTE_NORMAL),
      nil)
    guard handle != INVALID_HANDLE_VALUE else {
      throw Win32Error("CreateFileW")
    }
    defer { CloseHandle(handle) }

    var maxComponentLength: DWORD = 0
    let result = GetVolumeInformationByHandleW(
      handle,
      nil,
      0,
      nil,
      &maxComponentLength,
      nil,
      nil,
      0)
    guard result else {
      throw Win32Error("GetVolumeInformationByHandleW")
    }
  }
}
