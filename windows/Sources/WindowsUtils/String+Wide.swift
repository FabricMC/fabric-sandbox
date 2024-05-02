import WinSDK

extension String {
  // Convert a String to a UTF-16 wide string
  public var wide: [UInt16] {
    return self.withCString(encodedAs: UTF16.self) { buffer in
      [UInt16](unsafeUninitializedCapacity: self.utf16.count + 1) {  // +1 for null terminator
        wcscpy_s($0.baseAddress, $0.count, buffer)
        $1 = $0.count
      }
    }
  }
}
