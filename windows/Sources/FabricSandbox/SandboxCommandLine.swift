import Sandbox
import WinSDK
import WindowsUtils

/// A list of jvm properties that set where the native binaries are loaded from.

private let nativePathProperties = [
  "java.library.path",
  "jna.tmpdir",
  "org.lwjgl.system.SharedLibraryExtractPath",
  "io.netty.native.workdir",
]

private let propsToRewrite =
  nativePathProperties + [
    //"log4j.configurationFile"
  ]

class SandboxCommandLine {
  let args: [String]

  init(_ args: [String]) {
    self.args = args
  }

  func getApplicationPath() throws -> File? {
    let first = args.first
    guard let first = first else {
      return nil
    }
    let path = File(first)

    if path.isSymbolicLink() {
      return try path.resolveSymbolicLink()
    }

    return path
  }

  // Remove the last 2 slashes from the app path
  func getJavaHome() throws -> File? {
    return try getApplicationPath()?.parent()?.parent()
  }

  func getJvmProp(_ propName: String) -> String? {
    let prop = "-D\(propName)="
    for arg in args {
      if arg.starts(with: prop) {
        return String(arg.dropFirst(prop.count))
      }
    }
    return nil
  }

  private func usesArgsFile() -> Bool {
    return args.contains { $0.starts(with: "@") }
  }

  private func getArgsExpandingArgsFiles() throws -> [String] {
    if !usesArgsFile() {
      return args
    }

    var newArgs: [String] = []
    for arg in args {
      if arg.starts(with: "@") {
        let file = File(String(arg.dropFirst()))
        let lines = try file.readString().split(separator: "\r\n").map { $0.trimmed() }
        newArgs.append(contentsOf: lines)
      } else {
        newArgs.append(arg)
      }
    }
    return newArgs
  }

  func isDevEnv() -> Bool {
    return getJvmProp("fabric.development") == "true"
  }

  func getAssetsDir() -> File? {
    let assetsDir = args.firstIndex(of: "--assetsDir")
    guard let index = assetsDir, index + 1 < args.count else {
      return nil
    }
    return File(args[index + 1])
  }

  // Returns the arguments to pass to the sandboxed JVM.
  func getSandboxArgs(dotMinecraftDir: File, sandboxRoot: File, namedPipePath: String, extraJvmArgs: [String] = []) throws
    -> [String]
  {
    var args = try getArgsExpandingArgsFiles()
    var jvmArgsIndex = getJvmProp("java.io.tmpdir") == nil ? -1 : 1
    var foundVersionType = false
    let isDevEnv = isDevEnv()

    // Set the application path, this will resolve the path to the correct executable if it is a symlink.
    if let appPath = try getApplicationPath() {
      args[0] = appPath.path()
    }

    var classpathMap: [String: String] = [:]

    for i in 0..<args.count {
      if args[i] == "net.fabricmc.sandbox.Main" {
        // Replace the main class with the runtime entrypoint
        args[i] = "net.fabricmc.sandbox.runtime.Main"
      } else if args[i] == "-classpath" || args[i] == "-cp" {
        // Rewrite the classpath to ensure that all of the entries are within the sandbox.
        args[i + 1] = try rewriteClasspath(
          args[i + 1], dotMinecraftDir: dotMinecraftDir, sandboxRoot: sandboxRoot, classpathMap: &classpathMap)
      } else if args[i] == "--versionType" {
        // Prefix the version type with "Sandbox", so it is clear that the game is running in a sandbox.
        foundVersionType = true
        if args[i + 1] != "release" {
          args[i + 1] = "\(args[i + 1])/Sandbox"
        } else {
          args[i + 1] = "Sandbox"
        }
      } else if args[i] == "--gameDir" {
        // Replace the game directory with the sandbox root.
        args[i + 1] = sandboxRoot.path()
      } else if args[i] == "--assetsDir" && !isDevEnv {
        // Replace the assets directory with the sandbox assets directory, in a dev env the assets dir will be granted read access.
        args[i + 1] = sandboxRoot.child("assets").path()
      } else if args[i].starts(with: "-Dfabric.remapClasspathFile=") {
          // Rewrite the remap classpath file to ensure that all of the entries are within the sandbox.
          let file = File(String(args[i].dropFirst("-Dfabric.remapClasspathFile=".count)))
          args[i] = "-Dfabric.remapClasspathFile=\(try rewriteRemapClasspathFile(file, sandboxRoot: sandboxRoot).path())"
      }

      if args[i].starts(with: "-D") && jvmArgsIndex < 0 {
        // Find the first JVM argument, so we can insert our own at the same point.
        jvmArgsIndex = i
      } 

      for prop in propsToRewrite {
        let prefix = "-D\(prop)="
        if args[i].starts(with: prefix) {
          let value = File(String(args[i].dropFirst(prefix.count)))
          guard value.isChild(of: dotMinecraftDir) else {
            continue
          }
          let relativePath = value.relative(to: dotMinecraftDir)
          let newPath = sandboxRoot.child(relativePath)
          args[i] = "-D\(prop)=\(newPath.path())"
        }
      }
    }

    if jvmArgsIndex != -1 {
      if getJvmProp("java.io.tmpdir") == nil {
        args.insert("-Djava.io.tmpdir=\(sandboxRoot.child("temp"))", at: jvmArgsIndex)
      }

      for prop in nativePathProperties {
        if getJvmProp(prop) == nil {
          args.insert("-D\(prop)=\(sandboxRoot.child("temp").child("bin"))", at: jvmArgsIndex)
        }
      }

      args.insert("-Dsandbox.namedPipe=\(namedPipePath)", at: jvmArgsIndex)

      args.insert(contentsOf: extraJvmArgs, at: jvmArgsIndex)

      // Enable this to debug the sandboxed process, you will need to exempt the sandbox from the loopback networking like so:
      // CheckNetIsolation.exe LoopbackExempt -is -p=<SID>
      //args.insert("-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:5055", at: jvmArgsIndex)
    } else {
      logger.warning("Failed to find any JVM arguments, sandbox may not work correctly")
    }

    if !foundVersionType {
      args.append("--versionType")
      args.append("Sandbox")
    }

    // Remove any javaagent arguments
    args.removeAll { $0.starts(with: "-javaagent") }

    logger.debug("Classpath map: \(classpathMap)")

    for name in ["fabric.gameJarPath", "fabric.gameJarPath.client", "fabric.gameJarPath.server"] {
      SandboxCommandLine.modifyJvmProp(name: name, args: &args) { value in
        let classPath = value.split(separator: ";")
        var newClasspath: [String] = []

        for path in classPath {
          let file = File(String(path))
          let newPath = classpathMap[file.path()]
          if newPath == nil && file.exists() {
            logger.warning("Failed to find classpath entry for \(path)")
          }

          newClasspath.append(newPath ?? String(path))
        }

        return newClasspath.joined(separator: ";")
      }
    }

    SandboxCommandLine.modifyJvmProp(name: "fabric.classPathGroups", args: &args) { value in
      let groups = value.split(separator: ";;")
      var newGroups: [String] = []

      for group in groups {
        let classPath = group.split(separator: ";")
        var newClasspath: [String] = []

        for path in classPath {
          let file = File(String(path))
          let newPath = classpathMap[file.path()]
          if newPath == nil && file.exists() {
            logger.warning("Failed to find classpath entry for \(path)")
          }
          newClasspath.append(newPath ?? String(path))
        }

        newGroups.append(newClasspath.joined(separator: ";"))
      }

      return newGroups.joined(separator: ";;")
    }

    // TODO if an args file was used, we should write a new one with the updated args
    return args
  }

  // Read the classpath from the arguments and copy the files to the sandbox, returning the new classpath.
  func rewriteClasspath(_ classPathArgument: String, dotMinecraftDir: File, sandboxRoot: File, classpathMap: inout [String: String])
    throws -> String
  {
    let classPath = classPathArgument.split(separator: ";")
    var newClasspath: [String] = []

    // Used to store entries that are outside of the minecraft install dir
    // Lazily created to avoid creating the directory if it is not needed.
    let classpathDir = sandboxRoot.child(".classpath")
    try classpathDir.delete()

    for path in classPath {
      let source = File(String(path))

      guard source.exists() else {
        logger.warning("Classpath entry does not exist: \(source)")
        continue
      }

      if !source.isChild(of: dotMinecraftDir) {
        try classpathDir.createDirectory()

        var name = source.name()
        if source.isDirecotry() {
          let hash = try Checksum.hex(source.path(), .md5)
          name += "_" + hash.prefix(8)
        }

        // The classpath entry is not in the minecraft install dir, copy it to the sandbox.
        let target = classpathDir.child(name)
        logger.debug("Copying classpath entry to sandbox: \(source.path()) -> \(target.path())")
        try source.copy(to: target)
        newClasspath.append(target.path())
        classpathMap[source.path()] = target.path()
      } else {
        // The classpath entry is located within the minecraft jar, so will be mounted into the sandbox.
        let relativePath = source.relative(to: dotMinecraftDir)
        let sandboxPath = sandboxRoot.child(relativePath)
        newClasspath.append(sandboxPath.path())
        classpathMap[source.path()] = sandboxPath.path()
      }
    }
    return newClasspath.joined(separator: ";")
  }

  func rewriteRemapClasspathFile(_ classPathFile: File, sandboxRoot: File) throws -> File {
    let entries = try classPathFile.readString().split(separator: ";").map { File($0.trimmed()) }
    let classpathDir = sandboxRoot.child(".remapClasspath")
    try classpathDir.delete()

    var newEntries: [File] = []

    for entry in entries {
      guard entry.exists() else {
        logger.warning("Remap classpath entry does not exist: \(entry)")
        continue
      }

      if !entry.isChild(of: sandboxRoot) {
        try classpathDir.createDirectory()

        let target = classpathDir.child(entry.name())
        logger.debug("Copying remap classpath entry to sandbox: \(entry.path()) -> \(target.path())")
        try entry.copy(to: target)
        newEntries.append(target)
      } else {
        newEntries.append(entry)
      }
    }

    let newClasspathFile = classpathDir.child("remapClasspath.txt")
    try newClasspathFile.writeString(newEntries.map { $0.path() }.joined(separator: ";"))
    return newClasspathFile
  }

  private static func modifyJvmProp(name: String, args: inout [String], _ func: (String) -> String) {
    let prop = "-D\(name)="
    for i in 0..<args.count {
      if args[i].starts(with: prop) {
        args[i] = prop + `func`(String(args[i].dropFirst(prop.count)))
        return
      }
    }

    logger.debug("Failed to modify JVM property: \(name)")
  }
}
