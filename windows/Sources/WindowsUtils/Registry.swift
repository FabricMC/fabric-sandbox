import WinSDK

public struct Registry {
  public static func getStringValue(hive: Hive, key: String, name: String) throws -> String? {
    var size: DWORD = 0
    var result = RegGetValueW(hive.hkey, key.wide, name.wide, DWORD(RRF_RT_REG_SZ), nil, nil, &size)
    if result == ERROR_FILE_NOT_FOUND {
      return nil
    }
    guard result == ERROR_SUCCESS else {
      throw registryError("RegGetValueW", result)
    }

    var buffer = [WCHAR](repeating: 0, count: Int(size) / MemoryLayout<WCHAR>.size)
    result = RegGetValueW(hive.hkey, key.wide, name.wide, DWORD(RRF_RT_REG_SZ), nil, &buffer, &size)
    guard result == ERROR_SUCCESS else {
      throw registryError("RegGetValueW", result)
    }

    // Remove both null terminators
    buffer.removeLast()
    buffer.removeLast()

    return String(decoding: buffer, as: UTF16.self)
  }

  public static func setStringValue(hive: Hive, key: String, name: String, value: String) throws {
    let result = RegSetKeyValueW(
      hive.hkey, key.wide, name.wide, DWORD(REG_SZ), value.wide,
      DWORD(value.utf16.count * MemoryLayout<WCHAR>.size))
    guard result == ERROR_SUCCESS else {
      throw registryError("RegSetKeyValueW", result)
    }
  }

  public static func createKey(hive: Hive, key: String, access: Access = .readWrite) throws -> Bool
  {
    let key = key + "\0"
    var hkey: HKEY? = nil
    var disposition: DWORD = 0
    let result = RegCreateKeyExW(
      hive.hkey, key.wide, 0, nil, 0, access.value, nil, &hkey, &disposition)
    guard result == ERROR_SUCCESS else {
      throw registryError("RegCreateKeyExW", result)
    }
    return disposition == REG_CREATED_NEW_KEY
  }

  public static func deleteValue(hive: Hive, key: String, name: String) throws {
    let result = RegDeleteKeyValueW(hive.hkey, key.wide, name.wide)
    guard result == ERROR_SUCCESS else {
      throw registryError("RegDeleteKeyValueW", result)
    }
  }

  internal static func registryError(_ message: String, _ status: LSTATUS) -> Win32Error {
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(MAX_PATH))
    defer { buffer.deallocate() }
    let _ = FormatMessageW(
      DWORD(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS),
      nil, DWORD(status), DWORD(0), buffer, DWORD(MAX_PATH), nil)
    let status = String(decodingCString: buffer, as: UTF16.self)
    return Win32Error(message + " (\(status.dropLast(2)))")
  }
}

public enum Hive {
  case classesRoot
  case currentUser
  case localMachine
  case users
  case currentConfig

  var hkey: HKEY {
    switch self {
    case .classesRoot:
      return HKEY_CLASSES_ROOT
    case .currentUser:
      return HKEY_CURRENT_USER
    case .localMachine:
      return HKEY_LOCAL_MACHINE
    case .users:
      return HKEY_USERS
    case .currentConfig:
      return HKEY_CURRENT_CONFIG
    }
  }
}

public enum Access {
  case read
  case write
  case readWrite

  // https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-key-security-and-access-rights
  var value: DWORD {
    switch self {
    case .read:
      return 0x20019  // KEY_READ
    case .write:
      return 0x20006  // KEY_WRITE
    case .readWrite:
      return 0xF003F  // KEY_ALL_ACCESS
    }
  }
}
