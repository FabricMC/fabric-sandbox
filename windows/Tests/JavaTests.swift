import Sandbox
import Testing
import WindowsUtils

@Suite(.serialized) struct JavaTests {
  @Test func testHelloWorld() throws {
    let output = try runJava(
      """
      public class Main {
        public static void main(String[] args) {
            \(getLoadLibraries())
            System.out.println("Hello, World!");
        }
      }
      """)
    #expect(output == "Hello, World!")
  }

  @Test func testCreateTempFile() throws {
    let output = try runJava(
      """
      import java.io.File;
      import java.io.IOException;

      public class Main {
        public static void main(String[] args) throws IOException {
            \(getLoadLibraries())
            File.createTempFile("test", ".test");
            System.out.println("Ok");
        }
      }
      """)
    #expect(output == "Ok")
  }

  @Test func testCreateZipFile() throws {
    let output = try runJava(
      """
      import java.io.IOException;
      import java.net.URI;
      import java.net.URISyntaxException;
      import java.nio.file.FileSystem;
      import java.nio.file.FileSystems;
      import java.nio.file.Files;
      import java.nio.file.Path;
      import java.util.Collections;

      class Scratch {
        public static void main(String[] args) throws IOException {
            \(getLoadLibraries())
            Path zip = Files.createTempFile("test", ".zip");
            Files.delete(zip);
            try (FileSystem fs = FileSystems.newFileSystem(toJarUri(zip), Collections.singletonMap("create", "true"))) {
                if (fs.isReadOnly()) throw new IOException("The jar file can't be written");
            }
            System.out.println("Ok");
        }

        private static URI toJarUri(Path path) {
            URI uri = path.toUri();
            try {
                return new URI("jar:" + uri.getScheme(), uri.getHost(), uri.getPath(), uri.getFragment());
            } catch (URISyntaxException e) {
                throw new RuntimeException("can't convert path "+path+" to uri", e);
            }
        }
      }
      """)
    #expect(output == "Ok")
  }
}

private func runJava(_ source: String) throws -> String {
  let tempDir = try createTempDir()
  defer {
    try! tempDir.delete()
  }
  let sourceFile = tempDir.child("Main.java")
  try sourceFile.writeString(source)

  let javaHome = try getJavaHome()
  let javaExe = javaHome.child("bin").child("java.exe")

  let container = try AppContainer.create(
    name: "Test Sandbox" + randomString(length: 10), description: "Test Sandbox", capabilities: [],
    lpac: false)

  let driveLetter = MountedDisk.getNextDriveLetter(perfered: "S")
  guard let driveLetter = driveLetter else {
    throw SandboxError("No available drive letters")
  }

  let mountedDisk = try MountedDisk(path: tempDir, driveLetter: driveLetter)
  defer {
    try! mountedDisk.unmount()
  }

  try grantAccess(
    javaHome, appContainer: container, accessPermissions: [.genericRead, .genericExecute])
  try grantAccess(
    File(mountedDisk.drivePath), appContainer: container, accessPermissions: [.genericAll])
  try grantAccess(
    try getModuleFileName().parent()!, appContainer: container,
    accessPermissions: [.genericRead, .genericExecute])
  try grantAccess(
    try findSwiftRuntimeDirectory(), appContainer: container,
    accessPermissions: [.genericRead, .genericExecute])

  let outputConsumer = TestOutputConsumer()
  let mountedTemp = File(mountedDisk.drivePath).child("tmp")
  try mountedTemp.createDirectory()

  let args = [javaExe.path(), "-Djava.io.tmpdir=\(mountedTemp.path())", "Main.java"]
  let process = SandboxedProcess(
    application: javaExe, commandLine: args, workingDirectory: File(mountedDisk.drivePath),
    container: container, outputConsumer: outputConsumer)
  let exitCode = try process.run()
  #expect(exitCode == 0)
  return outputConsumer.trimmed()
}

private func getJavaHome() throws -> File {
  let javaHome = try getEnvironmentVarible("JAVA_HOME")
  guard let javaHome = javaHome else {
    throw SandboxError("JAVA_HOME environment variable not set")
  }
  return File(javaHome)
}

private func getLoadLibraries() -> String {
  let swiftBin = try! findSwiftRuntimeDirectory()
  let path = swiftBin.path(separator: "\\\\")
  return """
    System.load("\(path)\\\\swiftCore.dll");
    System.load("\(path)\\\\BlocksRuntime.dll");
    System.load("\(path)\\\\swiftWinSDK.dll");
    System.load("\(path)\\\\swiftSwiftOnoneSupport.dll");
    System.load("\(path)\\\\swiftCRT.dll");
    System.load("\(getHookPath())");
    """
}

private func getHookPath() -> String {
  let hookDll = try! getModuleFileName().parent()!.child("Hook.dll")
  return hookDll.path()
}

private func findSwiftRuntimeDirectory() throws -> File {
  let path = try getEnvironmentVarible("PATH")!
  let paths = path.split(separator: ";")

  for path in paths {
    let filePath = File(String(path))
    if filePath.child("swiftWinSDK.dll").exists() {
      return filePath
    }
  }

  throw SandboxError("Swift runtime directory not found")
}
