import Sandbox
import WindowsUtils
import Logging

var logger = Logger(label: "net.fabricmc.sandbox.packager")
logger.logLevel = .debug

let options = try getOptions()

logger.info("Packaging for \(options.arch) in \(options.directory)")

let wixVersion = try SwiftRedistributables.getWixVersion()
logger.debug("Wix version: \(wixVersion)")

let packageDir = options.directory.child("package")

try resetDir(packageDir)

let swiftRedistributables = try SwiftRedistributables.extractRedistributables(
  arch: options.arch, out: options.directory.child("redistributables"))

let vc143CRT = try VisualStudio.vc143CRT(arch: options.arch)

let vsRedistributables: [String: File] = try vc143CRT.directoryContents().reduce(into: [:]) {
  $0[$1.name()] = $1
}

let redistributables = swiftRedistributables.merging(vsRedistributables) { $1 }

let dlls = try copyDlls(packageDir, arch: options.arch, redistributables: redistributables)

try options.directory.child("FabricSandbox.dll").copy(to: packageDir.child("FabricSandbox.dll"))

try options.directory.child("Hook.dll").copy(to: packageDir.child("FabricSandboxHook.dll"))

try writeLibraryList(
  to: packageDir.child("sandbox.libs"), libraries: dlls + ["FabricSandbox.dll"])

try writeLibraryList(
  to: packageDir.child("runtime.libs"), libraries: dlls + ["FabricSandboxHook.dll"])

logger.info("Done!")

func copyDlls(_ packageDir: File, arch: Architecture, redistributables: [String: File]) throws -> [String] {
  let swiftDlls = [
    "swiftWinSDK.dll",
    "swiftCore.dll",
    "swiftCRT.dll",
    "swiftSwiftOnoneSupport.dll",
    "BlocksRuntime.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll",
    "msvcp140.dll",
  ]

  // Copy all swift dlls to the package directory
  for dll in swiftDlls {
    let source = redistributables[dll]
    guard let source = source else {
      throw PackagerError("Could not find redistributable: \(dll)")
    }

    let destination = packageDir.child(dll)

    guard try VisualStudio.getDllArchitecture(dll: source) == arch else {
      throw PackagerError("Architecture mismatch for \(dll)")
    }

    try source.copy(to: destination)
  }

  return swiftDlls
}

func writeLibraryList(to: File, libraries: [String]) throws {
  let packageDir = to.parent()!
  let sorted = try sortDlls(inputs: libraries.map { packageDir.child($0) })
  try to.writeString(sorted.joined(separator: "\n"))
}

func resetDir(_ dir: File) throws {
  if dir.exists() {
    try dir.delete()
  }
  try dir.createDirectory()
}

func run(_ exe: File, args: [String], searchPath: Bool = false) throws -> String {
  logger.debug("Running \(exe.path()) \(args.joined(separator: " "))")

  let output = CollectingOutputConsumer()
  // Not actually sandboxed, but we can reuse the code :)
  let process = SandboxedProcess(
    application: exe, commandLine: [exe.path()] + args,
    workingDirectory: try getWorkingDirectory(), container: nil, outputConsumer: output,
    searchPath: searchPath)
  let exitCode = try process.run()
  var str = output.output
  if str.count > 1 {
    str.removeLast(1)  // remove trailing newline
  }
  guard exitCode == 0 else {
    logger.error("\(str)")
    throw PackagerError("Process exited with code \(exitCode)")
  }
  return str
}

class CollectingOutputConsumer: OutputConsumer {
  var output = ""
  func consume(_ text: String) {
    output += text
  }
}

struct Options {
  var arch: Architecture
  var directory: File
}

func getOptions() throws -> Options {
  let commandLine = try getCommandLine()

  var archStr: String = compileArchitecture.name
  var directory = try getModuleFileName().parent()!

  for arg in commandLine {
    if arg.starts(with: "--arch=") {
      archStr = String(arg.dropFirst("--arch=".count)).lowercased()
    } else if arg.starts(with: "--dir=") {
      directory = File(String(arg.dropFirst("--dir=".count)))
    } else if arg.starts(with: "-") {
      throw PackagerError("Unknown argument \(arg)")
    }
  }

  let arch: Architecture
  switch archStr {
  case "aarch64":
    arch = .arm64
  case "arm64":
    arch = .arm64
  case "x86_64":
    arch = .x64
  default:
    throw PackagerError("Unknown architecture \(archStr)")
  }

  return Options(arch: arch, directory: directory)
}

public struct PackagerError: Error {
  let message: String

  public init(_ message: String) {
    self.message = message
  }
}
