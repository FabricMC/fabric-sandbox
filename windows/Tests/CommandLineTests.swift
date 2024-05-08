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

  private func processCommandLine(
    _ args: [String], dotMinecraftDir: File = File("C:/.minecraft"),
    sandboxRoot: File = File("S:")
  ) throws -> [String] {
    let sandboxCommandLine = SandboxCommandLine(["java", "-Dtest"] + args)
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
