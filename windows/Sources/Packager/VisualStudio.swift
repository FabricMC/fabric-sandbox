import WinSDK
import WindowsUtils

struct VisualStudio {
  static let dumpBin: File = {
    let dumpBin = try! find(
      "**/Host\(compileArchitecture.name)/\(compileArchitecture.name)/dumpbin.exe")
    return dumpBin
  }()

  static func vc143CRT(arch: Architecture) throws -> File {
    return try find("**\\\(arch.name)\\Microsoft.VC143.CRT")
  }

  static func find(_ query: String) throws -> File {
    let output = try run(getVswhere(), args: ["-latest", "-find", query], searchPath: true)
    let split = output.split(separator: "\r\n")
    guard split.count > 0 else {
      throw PackagerError("Could not find \(query)")
    }
    return File(String(split[0]))
  }

  static func getVswhere() throws -> File {
    let programFiles = try getEnvironmentVarible("ProgramFiles(x86)")!
    let vswhere = File(programFiles).child("Microsoft Visual Studio").child("Installer").child(
      "vswhere.exe")
    guard vswhere.exists() else {
      throw PackagerError("Could not find vswhere.exe")
    }
    return vswhere
  }

  /// Returns a list of dll dependencies for the given dll
  static func getDllDependencies(dll: File) throws -> [String] {
    guard dll.exists() else {
      throw PackagerError("\(dll) does not exist")
    }

    guard dumpBin.exists() else {
      throw PackagerError("\(dumpBin) does not exist")
    }

    let output = try run(dumpBin, args: ["/dependents", dll.path()])
    let lines = output.split(separator: "\r\n")

    // Primitive parsing of the ouput
    var dependencies = [String]()
    for line in lines {
      guard line.contains(".dll") && !line.contains("Dump of file") else {
        continue
      }
      dependencies.append(String(line.filter { $0 != " " }))
    }
    return dependencies
  }

  static func getDllArchitecture(dll: File) throws -> Architecture {
    guard dll.exists() else {
      throw PackagerError("\(dll) does not exist")
    }

    guard dumpBin.exists() else {
      throw PackagerError("\(dumpBin) does not exist")
    }

    let output = try run(dumpBin, args: ["/headers", dll.path()])
    if output.contains("machine (ARM64)") {
      return .arm64
    } else if output.contains("machine (x64) (ARM64X)") {
      // ARM64X can be loaded into both and x64 and ARM64 process
      return .arm64
    } else if output.contains("machine (x64)") {
      return .x64
    } else {
      throw PackagerError("Could not determine architecture of \(dll.path())")
    }
  }
}
