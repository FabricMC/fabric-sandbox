import WinSDK
import WinSDKExtras
import WindowsUtils

// Copied from https://github.com/apple/swift/blob/ee24bdf06f59d05fea996c230eb4024aa04dd4f5/stdlib/public/Platform/Platform.swift#L153 saves needing to import Foundation

private var stdout: UnsafeMutablePointer<FILE> { return __acrt_iob_func(1) }

public class SandboxedProcess {
  let application: String
  let commandLine: [String]
  let workingDirectory: String
  let container: AppContainer?
  let outputConsumer: OutputConsumer
  let searchPath: Bool

  public init(
    application: File, commandLine: [String], workingDirectory: File, container: AppContainer?,
    outputConsumer: OutputConsumer? = nil, searchPath: Bool = false
  ) {
    self.application = application.path()
    self.commandLine = commandLine
    self.workingDirectory = workingDirectory.path()
    self.container = container
    self.outputConsumer = outputConsumer ?? PrintOutputConsumer()
    self.searchPath = searchPath
  }

  public func run() throws -> Int {
    var securityAttributes = container?.attributes.map { $0.sidAttributes } ?? []
    return try securityAttributes.withUnsafeMutableBufferPointer { securityAttributes in
      var attributes: [ProcThreadAttribute] = []

      if let container = container {
        attributes.append(
          SecurityCapabilitiesProcThreadAttribute(
            container: container, securityAttributes: securityAttributes))
        if container.lpac {
          attributes.append(LessPrivilegedAppContainerProcThreadAttribute())
        }
      }

      let procThreadAttributeList = try ProcThreadAttributeList(attributes: attributes)

      var startupInfo = STARTUPINFOEXW(
        StartupInfo: STARTUPINFOW(),
        lpAttributeList: procThreadAttributeList.attributeList
      )
      startupInfo.StartupInfo.dwFlags |= STARTF_USESTDHANDLES
      startupInfo.StartupInfo.cb = DWORD(MemoryLayout<STARTUPINFOEXW>.size)

      var securityAttributes = SECURITY_ATTRIBUTES(
        nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
        lpSecurityDescriptor: nil,
        bInheritHandle: true
      )

      var readPipe: HANDLE? = nil
      var writePipe: HANDLE? = nil

      var result = CreatePipe(&readPipe, &writePipe, &securityAttributes, 0)

      guard result, let readPipe = readPipe, let writePipe = writePipe else {
        throw Win32Error("CreatePipe")
      }

      defer {
        CloseHandle(readPipe)
        CloseHandle(writePipe)
      }

      result = SetHandleInformation(readPipe, HANDLE_FLAG_INHERIT, 0)
      guard result else {
        throw Win32Error("SetHandleInformation")
      }

      startupInfo.StartupInfo.hStdOutput = writePipe
      startupInfo.StartupInfo.hStdError = writePipe
      return try createSandboxProcess(
        readPipe: readPipe, writePipe: writePipe, startupInfo: &startupInfo)
    }
  }

  internal func createSandboxProcess(
    readPipe: HANDLE, writePipe: HANDLE, startupInfo: inout STARTUPINFOEXW
  ) throws -> Int {
    let commandLine = formatCommandLine(commandLine)
    fflush(stdout)

    return try application.withCString(encodedAs: UTF16.self) { application throws in
      return try commandLine.withCString(encodedAs: UTF16.self) { commandLine throws in
        return try workingDirectory.withCString(encodedAs: UTF16.self) { workingDirectory throws in
          var processInformation = PROCESS_INFORMATION()
          let result = CreateProcessW(
            searchPath ? nil : application,
            UnsafeMutablePointer<WCHAR>(mutating: commandLine),  // This can mutate the string!!
            nil,
            nil,
            true,  // inherit handles
            DWORD(EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED),
            nil,
            workingDirectory,
            &startupInfo.StartupInfo,
            &processInformation
          )
          guard result else {
            throw Win32Error("CreateProcessW")
          }

          defer {
            CloseHandle(processInformation.hProcess)
            CloseHandle(processInformation.hThread)
          }

          let jobObject = JobObject()
          try jobObject.killOnJobClose()
          try jobObject.assignProcess(processInformation)

          // The child process now owns the write end of the pipe, so close it
          CloseHandle(writePipe)

          let readThread = try ReadThread(readPipe: readPipe, outputConsumer: outputConsumer)
          readThread.start()

          // Now let the child process run
          ResumeThread(processInformation.hThread)

          WaitForSingleObject(processInformation.hProcess, INFINITE)
          var exitCode: DWORD = 0
          let _ = GetExitCodeProcess(processInformation.hProcess, &exitCode)

          try readThread.join()
          return Int(exitCode)
        }
      }
    }
  }
}

internal func formatCommandLine(_ args: [String]) -> String {
  return args.map { arg in
    if arg.contains(" ") {
      return "\"\(arg)\""
    } else {
      return arg
    }
  }.joined(separator: " ")
}

public protocol OutputConsumer {
  func consume(_ text: String)
}

class PrintOutputConsumer: OutputConsumer {
  func consume(_ text: String) {
    print(text, terminator: "")
    fflush(stdout)
  }
}

class ReadThread: Thread {
  let readPipe: HANDLE
  let outputConsumer: OutputConsumer

  init(readPipe: HANDLE, outputConsumer: OutputConsumer) throws {
    self.readPipe = readPipe
    self.outputConsumer = outputConsumer
    try super.init()
  }

  override func run() {
    var buffer = [UInt8](repeating: 0, count: 4096)
    var bytesRead: DWORD = 0

    while true {
      let result = ReadFile(readPipe, &buffer, DWORD(buffer.count) - 1, &bytesRead, nil)
      guard result, bytesRead > 0 else {
        break
      }

      buffer[Int(bytesRead)] = 0  // null-terminate

      let text = String(decodingCString: buffer, as: UTF8.self)
      outputConsumer.consume(text)
    }
  }
}
