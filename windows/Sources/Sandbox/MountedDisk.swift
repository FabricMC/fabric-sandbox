import WinSDK
import WindowsUtils

public class MountedDisk {
  public let path: File
  public let drivePath: String

  public init(path: File, driveLetter: Character) throws {
    self.path = path
    self.drivePath = String(driveLetter) + ":"

    if !DefineDosDeviceW(0, drivePath.wide, path.path().wide) {
      throw Win32Error("DefineDosDeviceW")
    }

    //if !SetVolumeLabelW(drivePath.wide, "Fabric Sandbox".wide) {
    //  try unmount(); // Clean up on error
    //  throw Win32Error("SetVolumeLabelW")
    //}
  }

  public func unmount() throws {
    if !DefineDosDeviceW(DWORD(DDD_REMOVE_DEFINITION), drivePath.wide, path.path().wide) {
      throw Win32Error("DefineDosDeviceW")
    }
  }

  public func root() -> File {
    return File(drivePath + "\\")
  }

  /// Returns a list of drive letters that are currently in use
  static func getUsedDriveLetters() -> [Character] {
    let drives = GetLogicalDrives()

    var driveLetters = [Character]()
    for i in 0..<26 {
      if drives & (1 << i) != 0 {
        driveLetters.append(Character(UnicodeScalar(UInt8(65 + i))))
      }
    }

    return driveLetters
  }

  /// Returns the next available drive letter
  /// If perfered is set, it will try to use that drive letter first
  /// Otherwise it will return the next available drive letter, starting from preferred rolling over to A
  /// Returns nil if no drive letters are available
  public static func getNextDriveLetter(perfered: Character) -> Character? {
    let usedDriveLetters = getUsedDriveLetters()

    // Check if the perfered drive letter is available, if so return it
    if !usedDriveLetters.contains(perfered) {
      return perfered
    }

    var count = 0
    var index = perfered.asciiValue! - 65

    while count < 26 {
      index += 1

      // Roll over to A
      if index >= 26 {
        index = 0
      }

      let letter = Character(UnicodeScalar(UInt8(65 + index)))
      if !usedDriveLetters.contains(letter) {
        return letter
      }

      count += 1
    }

    return nil
  }

}
