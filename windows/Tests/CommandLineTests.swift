import Testing
import WindowsUtils

@testable import FabricSandbox

struct CommandLineTests {
  // Test that the main class is replaced with the runtime entrypoint
  @Test func replaceMainClass() throws {
    let commandLine = try processCommandLine(["net.fabricmc.sandbox.Main"])
    expectContains(commandLine, ["net.fabricmc.sandbox.runtime.Main"])
  }

  // Test that a classpath entry within the .minecraft directory is rewritten to be read from the sandbox root
  @Test func rewriteClasspathDotMinecraftjar() throws {
    let dummmyDotMinecraftDir = try createTempDir(ext: ".minecraft")
    let dummySandboxRoot = try createTempDir(ext: ".sandbox")

    let binDir = dummmyDotMinecraftDir.child("bin")
    let dummyJar = binDir.child("test.jar")
    try binDir.createDirectory()
    try dummyJar.touch()

    let commandLine = try processCommandLine(
      ["-cp", dummyJar.path()], dotMinecraftDir: dummmyDotMinecraftDir,
      sandboxRoot: dummySandboxRoot)
    expectContains(commandLine, ["-cp", dummySandboxRoot.child("bin").child("test.jar").path()])
  }

  @Test func rewriteGameDir() throws {
    let commandLine = try processCommandLine([
      "net.fabricmc.sandbox.Main", "--gameDir", "C:/.minecraft",
    ])
    expectContains(commandLine, ["--gameDir", "S:/"])
  }

  // TODO this likely wont be correct for dev environments
  @Test func rewriteAssetsDir() throws {
    let commandLine = try processCommandLine([
      "net.fabricmc.sandbox.Main", "--assetsDir", "C:/.minecraft",
    ])
    expectContains(commandLine, ["--assetsDir", "S:/assets"])
  }

  @Test func setTempDir() throws {
    expectContains(try processCommandLine([]), ["-Djava.io.tmpdir=S:/temp"])
  }

  @Test func setNamedPipeProperty() throws {
    expectContains(try processCommandLine([]), ["-Dsandbox.namedPipe=C:/namedPipePath"])
  }

  @Test func setNativeDirProps() throws {
    expectContains(try processCommandLine([]), ["-Djava.library.path=S:/temp/bin"])
  }

  @Test func setVersionType() throws {
    expectContains(
      try processCommandLine(["--versionType", "release"]), ["--versionType", "Sandbox"])
    expectContains(
      try processCommandLine(["--versionType", "snapshot"]), ["--versionType", "snapshot/Sandbox"])
  }

  @Test func expandArgsFile() throws {
    let argsFile = try createTempDir().child("args.txt")
    try argsFile.writeString("arg1\r\narg2\r\n")
    let commandLine = try processCommandLine(["@\(argsFile.path())"])
    expectContains(commandLine, ["arg1", "arg2"])
  }

  @Test func resolveSymlinkApplication() throws {
    let tempDir = try File.getTempDirectory().randomChild()
    try tempDir.createDirectory()
    defer { try! tempDir.delete() }

    let link = tempDir.child("link.exe")
    let target = tempDir.child("target.exe")
    try target.touch()

    try link.createSymbolicLink(to: target)

    let commandLine = try processCommandLine([], applicationName: link.path())
    expectContains(commandLine, [target.path()])
  }

  @Test func rewriteRemapClasspathFile() throws {
    let tempDir = try File.getTempDirectory().randomChild()
    try tempDir.createDirectory()
    defer { try! tempDir.delete() }

    let remapClasspath = tempDir.child("remapClasspath.txt")
    let remapEntries = (0..<5).map { i in tempDir.child("file\(i).jar") }
    try remapEntries.forEach { try $0.touch() }
    try remapClasspath.writeString(remapEntries.map{$0.path()}.joined(separator: ";"))

    let sandboxRoot = tempDir.child("sandbox")
    let sandboxRemapClasspathFile = sandboxRoot.child(".remapClasspath").child("remapClasspath.txt")

    let commandLine = try processCommandLine(["-Dfabric.remapClasspathFile=\(remapClasspath.path())"], sandboxRoot: sandboxRoot)
    expectContains(commandLine, ["-Dfabric.remapClasspathFile=\(sandboxRemapClasspathFile.path())"])

    let sandboxRemapEntries = try sandboxRemapClasspathFile.readString().split(separator: ";").map { File(String($0)) }
    #expect(sandboxRemapEntries.count == remapEntries.count)

    for entry in sandboxRemapEntries {
      #expect(entry.isChild(of: sandboxRoot))
      #expect(entry.exists())
    }
  }

  private func processCommandLine(
    _ args: [String], dotMinecraftDir: File = File("C:/.minecraft"),
    sandboxRoot: File = File("S:"),
    applicationName: String = "java"
  ) throws -> [String] {
    let sandboxCommandLine = SandboxCommandLine([applicationName, "-Dtest"] + args)
    return try sandboxCommandLine.getSandboxArgs(
      dotMinecraftDir: dotMinecraftDir, sandboxRoot: sandboxRoot, namedPipePath: "C:/namedPipePath"
    )
  }

  private func expectContains(_ actual: [String], _ expected: [String]) {
    let contains = expected.allSatisfy { actual.contains($0) }

    if !contains {
      Issue.record("Expected \(actual) to contain \(expected)")
    }

    #expect(contains)
  }
}
