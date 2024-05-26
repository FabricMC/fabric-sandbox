import WinSDK

// Returns the command line arguments as an array of strings.

public func getCommandLine() throws -> [String] {
  let commandLinePtr = GetCommandLineW()
  guard let commandLinePtr = commandLinePtr else {
    throw Win32Error("GetCommandLineW")
  }

  var argc: Int32 = 0
  let argv = CommandLineToArgvW(commandLinePtr, &argc)
  guard let argv = argv else {
    throw Win32Error("CommandLineToArgvW")
  }
  defer {
    LocalFree(argv)
  }

  let args: [String] = (0..<Int(argc)).map { i in
    guard let arg = argv[i] else {
      fatalError("CommandLineToArgvW returned nil")
    }
    return String(decodingCString: arg, as: UTF16.self)
  }
  return args
}
