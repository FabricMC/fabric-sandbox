import Sandbox
import WinSDK
import WinSDKExtras
import WindowsUtils
import Logging

/// TODO: Add support for LPAC (Less Privileged AppContainer)

private let lpac = false

var logger = Logger(label: "net.fabricmc.sandbox")

class FabricSandbox {
  func run() throws {
    guard _IsWindows10OrGreater() else {
      throw SandboxError("Fabric Sandbox requires Windows 10 or later")
    }

    // Only allow one instance of the sandbox
    let mutex = CreateMutexW(nil, true, "FabricSandbox".wide)
    if GetLastError() == ERROR_ALREADY_EXISTS {
      throw SandboxError(
        "Fabric Sandbox is already running, only one instance is currently supported")
    }
    guard mutex != nil else {
      throw SandboxError("Failed to create mutex")
    }
    defer {
      ReleaseMutex(mutex)
    }

    logger.info("Fabric Sandbox")

    let commandLine = try getSandboxCommandLine()
    let workingDirectory = try getWorkingDirectory()
    let javaPath = try commandLine.getApplicationPath()
    let javaDirectory = try commandLine.getJavaHome()
    let isDevEnv = commandLine.isDevEnv()
    let dotMinecraft = isDevEnv ? workingDirectory : try getDotMinecraftDir()

    guard let javaPath = javaPath, let javaDirectory = javaDirectory else {
      throw SandboxError("Failed to get Java path or home")
    }

    if commandLine.getJvmProp("fabric.log.level") == "debug" {
      logger.logLevel = .debug
    }

    logger.debug("Working directory: \(workingDirectory)")
    logger.debug("Java path: \(javaPath)")
    logger.debug("Java home: \(javaDirectory)")
    logger.debug("Is development env: \(isDevEnv)")
    logger.debug(".minecraft: \(dotMinecraft)")

    guard workingDirectory.equals(dotMinecraft) || workingDirectory.isChild(of: dotMinecraft) else {
      // Currently we only mount 1 drive, so the working directory must be a child of .minecraft
      // This can be fixed by mounting both .minecraft and the working directory using separate drive letters
      throw SandboxError("Game/working directory must be a child of .minecraft")
    }

    let capabilities: [SidCapability] = [
      .wellKnown(WinCapabilityInternetClientSid),
      .wellKnown(WinCapabilityInternetClientServerSid),
      .wellKnown(WinCapabilityPrivateNetworkClientServerSid),
      // TODO look at custom capabilities when supporting LPAC
      // .custom("windowManagementSystem"),
    ]

    let container = try AppContainer.create(
      name: "Fabric Sandbox", description: "Fabric Sandbox", capabilities: capabilities,
      lpac: lpac)
    logger.info("AppContainer SID: \(container.sid)")

    let driveLetter = MountedDisk.getNextDriveLetter(perfered: "S")
    guard let driveLetter = driveLetter else {
      throw SandboxError("No available drive letters")
    }

    // Mount .minecraft to a drive letter
    let mountedDisk = try MountedDisk(path: dotMinecraft, driveLetter: driveLetter)
    defer {
      try! mountedDisk.unmount()
    }

    // E.g S:\
    let sandboxRoot = File(mountedDisk.drivePath)
    // E.g S:\profileName or S:\
    let sandboxWorkingDirectory = sandboxRoot.child(workingDirectory.relative(to: dotMinecraft))

    logger.debug("Sandbox root: \(sandboxRoot)")

    // Grant full access to the temp directory
    let tempDir = sandboxRoot.child("temp")
    try tempDir.createDirectory()
    defer {
      try? tempDir.delete()
    }

    if sandboxWorkingDirectory.equals(sandboxRoot) || isDevEnv {
      logger.debug("Working directory is root, granting access")
      // There is a vunerability in this case, as the sandboxed process will have write access to the sandbox and launcher files.
      // This makes it possible for a malicious mod to modify the launcher and escape the sandbox on the next launch.
      // Sadly this is likely the best we can do as this will be the default case for most users.
      // One possible option is to be even stricter and only allow write access to certain sub directories, such as the saves and logs directories.
      // This is hard to do as mods commonly write outside of these directories.

      // Grant full access to the mounted disk
      try grantAccess(
        sandboxRoot, trustee: container,
        accessPermissions: [.genericAll])

      if let assetsDir = commandLine.getAssetsDir(), isDevEnv {
        // Grant read access to the assets dir in dev
        try grantAccess(
          assetsDir, trustee: container,
          accessPermissions: [.genericRead])
      }

      if let log4jConfig = commandLine.getJvmProp("log4j.configurationFile") {
        // Grant read access to the log4j configuration file
        try grantAccess(
          File(log4jConfig), trustee: container,
          accessPermissions: [.genericRead])
      }
    } else {
      logger.debug("Working directory is not root, granting access")
      // Grant read and execute to .minecraft
      try grantAccess(
        sandboxRoot, trustee: container,
        accessPermissions: [.genericRead, .genericExecute])

      // Grant full access to the working directory
      try grantAccess(
        sandboxWorkingDirectory, trustee: container,
        accessPermissions: [.genericAll])

      try grantAccess(
        tempDir, trustee: container,
        accessPermissions: [.genericAll])
    }

    // Grant read and execute to Java home
    try grantAccess(
      javaDirectory, trustee: container,
      accessPermissions: [.genericRead, .genericExecute])

    // Create a named pipe server for IPC with the sandboxed process
    let namedPipeServer = try SandboxNamedPipeServer(
      pipeName: "\\\\.\\pipe\\FabricSandbox" + randomString(length: 10))

    // Grant access to the named pipe
    try grantAccess(
      namedPipeServer, trustee: container,
      accessPermissions: [.genericRead, .genericWrite])

    // Grant access to any of the active discord named pipes
    // TODO we might want to run this every so often to handle new pipes
    try grantAccessToDiscordPipes(trustee: container)

    let args = try commandLine.getSandboxArgs(
      dotMinecraftDir: dotMinecraft, sandboxRoot: sandboxRoot, namedPipePath: namedPipeServer.path)

    logger.debug("Args: \(args)")

    let process = SandboxedProcess(
      application: javaPath, commandLine: args,
      workingDirectory: sandboxWorkingDirectory,
      container: container)
    let exitCode = try process.run()

    if exitCode != 0 {
      logger.error("Java process exited with code \(exitCode)")
    }
  }

  internal func getDotMinecraftDir() throws -> File {
    let appData = try getEnvironmentVarible("APPDATA")
    guard let appData = appData else {
      throw SandboxError("APPDATA environment variable not found")
    }

    let minecraftDir = File(appData).child(".minecraft")
    guard minecraftDir.exists() else {
      throw SandboxError(".minecraft directory not found")
    }
    return minecraftDir
  }
}

private func getSandboxCommandLine() throws -> SandboxCommandLine {
  let args = try getCommandLine()
  let expanded = try applyDevLaunchInjectorArgs(args)
  return SandboxCommandLine(expanded)
}
