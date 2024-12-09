#if arch(x86_64)
  public let compileArchitecture = Architecture.x64
#elseif arch(arm64)
  public let compileArchitecture = Architecture.arm64
#endif
public enum Architecture: Sendable {
  case x64
  case arm64

  public var name: String {
    switch self {
    case .x64:
      return "x64"
    case .arm64:
      return "arm64"
    }
  }
}
