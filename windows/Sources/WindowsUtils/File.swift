import WinSDK

// A file API implementation using Win32 without using the swift foundation library.

public final class File: CustomStringConvertible, Sendable {
  static let pathSeparators: [Character] = ["/", "\\"]

  let parts: [String]

  public init(_ path: String) {
    self.parts = splitString(path, separators: File.pathSeparators)
  }

  init(_ parts: [String]) {
    self.parts = parts
  }

  public func path(separator: String = "/") -> String {
    if parts.count == 1 && parts.first!.contains(":") {
      return parts.first! + separator
    }

    return parts.joined(separator: separator)
  }

  public func parent() -> File? {
    if parts.count == 1 {
      return nil
    }
    return File(Array(parts.dropLast()))
  }

  public func child(_ name: String) -> File {
    return File(parts + splitString(name, separators: File.pathSeparators))
  }

  public func root() -> File {
    return File([parts.first ?? path()])
  }

  public func name() -> String {
    return parts.last!
  }

  public func ext() -> String? {
    let name = parts.last ?? ""
    let parts = splitString(name, separators: ["."])
    return parts.count > 1 ? parts.last : nil
  }

  public func randomChild(ext: String? = nil) -> File {
    let name = randomString(length: 10)
    let child = self.child(name + (ext ?? ""))
    return child
  }

  public func exists() -> Bool {
    let path = self.path()
    return GetFileAttributesW(path.wide) != INVALID_FILE_ATTRIBUTES
  }

  public func isDirecotry() -> Bool {
    let path = self.path()
    let attributes = GetFileAttributesW(path.wide)
    return attributes != INVALID_FILE_ATTRIBUTES
      && attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0
  }

  public func createDirectory(_ recursive: Bool = true) throws {
    guard !exists() else {
      return
    }

    if recursive {
      try parent()?.createDirectory(true)
    } else {
      guard self.parent()?.exists() != false else {
        throw fileError("Parent directory does not exist")
      }
    }

    let path = self.path()
    if !CreateDirectoryW(path.wide, nil) {
      throw win32Error("CreateDirectoryW")
    }
  }

  public func directoryContents() throws -> [File] {
    guard isDirecotry() else {
      throw fileError("Not a directory")
    }

    let searchPath = self.path(separator: "\\") + "\\*"
    var findData = WIN32_FIND_DATAW()
    let handle = FindFirstFileW(searchPath.wide, &findData)
    guard handle != INVALID_HANDLE_VALUE else {
      throw win32Error("FindFirstFileW")
    }

    var files: [File] = []
    defer { FindClose(handle) }

    repeat {
      let name: String = withUnsafeBytes(of: findData.cFileName) {
        $0.withMemoryRebound(to: WCHAR.self) {
          String(decodingCString: $0.baseAddress!, as: UTF16.self)
        }
      }
      if name != "." && name != ".." {
        files.append(self.child(name))
      }
    } while FindNextFileW(handle, &findData)

    return files
  }

  public func delete() throws {
    guard exists() else {
      return
    }

    var wpath = self.path(separator: "\\").wide
    wpath.append(0)  // Must be double null terminated

    try wpath.withUnsafeBufferPointer {
      var fileOp = SHFILEOPSTRUCTW()
      fileOp.wFunc = UINT(FO_DELETE)
      fileOp.pFrom = $0.baseAddress
      fileOp.fFlags = FOF_NO_UI
      guard SHFileOperationW(&fileOp) == 0 else {
        throw win32Error("SHFileOperationW")
      }
    }
  }

  public func touch() throws {
    guard !self.exists() else {
      throw fileError("File already exists")
    }
    let _ = try FileHandle.create(
      self, access: DWORD(GENERIC_WRITE), shareMode: 0, creationDisposition: DWORD(CREATE_NEW),
      flagsAndAttributes: DWORD(FILE_ATTRIBUTE_NORMAL))
  }

  public func size() throws -> Int {
    let handle = try FileHandle.create(
      self, access: DWORD(GENERIC_READ), shareMode: DWORD(FILE_SHARE_READ),
      creationDisposition: DWORD(OPEN_EXISTING),
      flagsAndAttributes: DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED))

    var fileSize: LARGE_INTEGER = LARGE_INTEGER()
    let result = GetFileSizeEx(handle.handle, &fileSize)
    guard result else {
      throw win32Error("GetFileSizeEx")
    }
    return Int(fileSize.QuadPart)
  }

  public func writeString(_ string: String) throws {
    let handle = try FileHandle.create(
      self, access: DWORD(GENERIC_WRITE), shareMode: 0, creationDisposition: DWORD(CREATE_ALWAYS),
      flagsAndAttributes: DWORD(FILE_ATTRIBUTE_NORMAL))

    let data = Array(string.utf8)
    var bytesWritten: DWORD = 0
    let result = WriteFile(handle.handle, data, DWORD(data.count), &bytesWritten, nil)
    guard result, bytesWritten == data.count else {
      throw win32Error("WriteFile")
    }
  }

  public func readString(_ chunkSize: DWORD = 4096) throws -> String {
    let handle = try FileHandle.create(
      self, access: DWORD(GENERIC_READ), shareMode: DWORD(FILE_SHARE_READ),
      creationDisposition: DWORD(OPEN_EXISTING), flagsAndAttributes: DWORD(FILE_ATTRIBUTE_NORMAL))

    let size = try self.size()
    var buffer = [UInt8](repeating: 0, count: size)
    var bytesRead: DWORD = 0
    let result = ReadFile(handle.handle, &buffer, DWORD(size), &bytesRead, nil)
    guard result, bytesRead == DWORD(size) else {
      throw win32Error("ReadFile")
    }

    return String(decoding: buffer, as: UTF8.self)
  }

  public func copy(to: File) throws {
    guard exists() else {
      throw fileError("Source file does not exist")
    }

    guard !to.exists() else {
      throw to.fileError("Destination file already exists")
    }

    var from = self.path(separator: "\\").wide
    var to = to.path(separator: "\\").wide
    from.append(0)  // Must be double null terminated
    to.append(0)

    try from.withUnsafeBufferPointer { from in
      try to.withUnsafeBufferPointer { to in
        var fileOp = SHFILEOPSTRUCTW()
        fileOp.wFunc = UINT(FO_COPY)
        fileOp.pFrom = from.baseAddress
        fileOp.pTo = to.baseAddress
        fileOp.fFlags = FOF_NO_UI
        guard SHFileOperationW(&fileOp) == 0 else {
          throw win32Error("SHFileOperationW")
        }
      }
    }
  }

  /// Returns the relative path of this file to the given file.
  /// E.g if this file is "C:\foo\bar\baz.txt" and the given file is "C:\foo\" then the result is "bar\baz.txt"
  public func relative(to: File) -> String {
    let parts = self.parts
    let toParts = to.parts
    var commonPrefix = 0
    while commonPrefix < parts.count && commonPrefix < toParts.count
      && parts[commonPrefix] == toParts[commonPrefix]
    {
      commonPrefix += 1
    }
    var result = ""
    for _ in 0..<(toParts.count - commonPrefix) {
      result += "..\\"
    }
    result += parts[commonPrefix...].joined(separator: "\\")
    return result
  }

  /// Returns true if this file is a child of the given file.
  /// E.g if this file is "C:\foo\bar\baz.txt" and the given file is "C:\foo\" then the result is true
  public func isChild(of: File) -> Bool {
    let parts = self.parts
    let parentParts = of.parts
    if parts.count <= parentParts.count {
      return false
    }
    for i in 0..<parentParts.count {
      if parts[i] != parentParts[i] {
        return false
      }
    }
    return true
  }

  public func isSymbolicLink() -> Bool {
    let path = self.path()
    let attributes = GetFileAttributesW(path.wide)
    return attributes != INVALID_FILE_ATTRIBUTES
      && attributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0
  }

  public func resolveSymbolicLink() throws -> File {
    guard isSymbolicLink() else {
      return self
    }

    let handle = try FileHandle.create(
      self, access: DWORD(GENERIC_READ), shareMode: DWORD(FILE_SHARE_READ),
      creationDisposition: DWORD(OPEN_EXISTING),
      flagsAndAttributes: DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS))

    var buffer = [WCHAR](repeating: 0, count: Int(MAX_PATH))
    let length = GetFinalPathNameByHandleW(handle.handle, &buffer, DWORD(MAX_PATH), DWORD(0))

    guard length != 0 else {
      throw win32Error("GetFinalPathNameByHandleW")
    }

    let string = String(decodingCString: buffer, as: UTF16.self)
    // Remove the leading ?/
    return File(String(string.dropFirst(4)))
  }

  // Note: The user must be elevated or have developer mode enabled to create symbolic links.
  public func createSymbolicLink(to: File, isDirectory: Bool = false) throws {
    let fromPath = self.path().wide
    let toPath = to.path().wide
    let flags = DWORD(isDirectory ? SYMBOLIC_LINK_FLAG_DIRECTORY : 0) | DWORD(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)
    guard CreateSymbolicLinkW(fromPath, toPath, flags) != 0 else {
      throw win32Error("CreateSymbolicLinkW")
    }
  }

  public func equals(_ other: File) -> Bool {
    return self.parts == other.parts
  }

  public var description: String {
    return path()
  }

  public static func getTempDirectory() throws -> File {
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(MAX_PATH))
    defer { buffer.deallocate() }
    let length = GetTempPathW(DWORD(MAX_PATH), buffer)
    if length == 0 {
      throw Win32Error("GetTempPathW")
    }
    return File(String(decodingCString: buffer, as: UTF16.self))

  }

  fileprivate func win32Error(_ message: String) -> Win32Error {
    return Win32Error(message + " (\(self.path()))")
  }

  fileprivate func fileError(_ message: String) -> FileEror {
    return FileEror(message + " (\(self.path()))")
  }
}

func splitString(_ s: String, separators: [Character]) -> [String] {
  var parts: [String] = []
  var currentPart: String = ""
  for c in s {
    if separators.contains(c) {
      if !currentPart.isEmpty {
        parts.append(currentPart)
        currentPart = ""
      }
    } else {
      currentPart.append(c)
    }
  }
  if !currentPart.isEmpty {
    parts.append(currentPart)
  }
  return parts
}

public func randomString(length: Int) -> String {
  let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  return String((0..<length).map { _ in letters.randomElement()! })
}

struct FileEror: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

internal class FileHandle {
  let handle: HANDLE

  init(_ handle: HANDLE) {
    self.handle = handle
  }

  static func create(
    _ file: File, access: DWORD, shareMode: DWORD, creationDisposition: DWORD,
    flagsAndAttributes: DWORD
  ) throws -> FileHandle {
    let handle = CreateFileW(
      file.path().wide, access, shareMode, nil, creationDisposition, flagsAndAttributes, nil)
    guard handle != INVALID_HANDLE_VALUE, let handle = handle else {
      throw Win32Error("CreateFileW \(file.path())")
    }
    return FileHandle(handle)
  }

  deinit {
    CloseHandle(handle)
  }
}
