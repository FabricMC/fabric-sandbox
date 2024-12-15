import WinSDK
import WinSDKExtras
import WindowsUtils

public class AppContainer: Trustee {
  public let name: String
  public let sid: Sid
  public let trustee: TRUSTEE_W
  let attributes: [SidAndAttributes]
  // Less Privileged App Container
  let lpac: Bool
  fileprivate let mutex: AppContainerMutex

  fileprivate init(
    name: String, sid: Sid, attributes: [SidAndAttributes], lpac: Bool, mutex: AppContainerMutex
  ) {
    self.name = name
    self.sid = sid
    self.attributes = attributes
    self.lpac = lpac
    self.mutex = mutex
    self.trustee = TRUSTEE_W(
      pMultipleTrustee: nil,
      MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
      TrusteeForm: TRUSTEE_IS_SID,
      TrusteeType: TRUSTEE_IS_WELL_KNOWN_GROUP,
      ptstrName: sid.ptstrName
    )
  }

  deinit {
    DeleteAppContainerProfile(name.wide)
  }

  public static func create(
    name: String, description: String, capabilities: [SidCapability], lpac: Bool = false
  ) throws
    -> AppContainer
  {
    let mutex = try AppContainerMutex(name: name)

    let attributes = try capabilities.map { type in
      try SidAndAttributes.createWithCapability(type: type)
    }

    /* TODO: Reuse an existing AppContainer, we need to take into account the capabilities
    if let sid = getExisting(name) {
      return AppContainer(
        name: name, sid: sid, attributes: attributes, lpac: lpac, mutex: mutex)
    }
    */

    // Fow now delete an existing container if it exists
    let _ = DeleteAppContainerProfile(name.wide)

    var capabilities = attributes.map { $0.sidAttributes }
    var sid: PSID? = nil
    let result = capabilities.withUnsafeMutableBufferPointer { capabilities in
      CreateAppContainerProfile(
          name.wide, name.wide, description.wide,
          capabilities.count > 0 ? capabilities.baseAddress : nil,
          DWORD(capabilities.count), &sid)
    }
    guard result == S_OK, let sid = sid else {
      throw Win32Error("CreateAppContainerProfile", result: result)
    }

    return AppContainer(name: name, sid: Sid(sid), attributes: attributes, lpac: lpac, mutex: mutex)
  }

  private static func getExisting(_ name: String) -> Sid? {
    var sid: PSID? = nil
    let result = DeriveAppContainerSidFromAppContainerName(name.wide, &sid)

    guard result == S_OK, let sid = sid else {
      return nil
    }

    return Sid(sid)
  }
}

private class AppContainerMutex {
  let handle: HANDLE

  init(name: String) throws {
    let handle = CreateMutexW(nil, true, name.wide)
    if GetLastError() == ERROR_ALREADY_EXISTS {
      throw SandboxError("An AppContainer with the name '\(name)' is already running")
    }
    guard let handle = handle else {
      throw Win32Error("CreateMutexW")
    }
    self.handle = handle
  }

  deinit {
    CloseHandle(handle)
  }
}
