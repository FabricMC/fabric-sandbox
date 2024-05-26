import WinSDK
import WinSDKExtras
// Reads the existing ACL for the given path and adds an entry to it that grants the app container the specified access permissions.
import WindowsUtils

public func grantAccess(
  _ file: File, appContainer: AppContainer, accessPermissions: [AccessPermissions]
)
  throws
{
  let path = file.path()

  // Check that the path exists
  guard GetFileAttributesW(path.wide) != INVALID_FILE_ATTRIBUTES else {
    throw SandboxError("Path does not exist: '\(path)'")
  }

  // Read the existing ACL
  var acl: PACL? = nil
  var result = withUnsafeMutablePointer(to: &acl) {
    GetNamedSecurityInfoW(
      path.wide, SE_FILE_OBJECT, SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), nil, nil, $0, nil,
      nil)
  }
  guard result == ERROR_SUCCESS, let acl = acl else {
    throw Win32Error("GetNamedSecurityInfoW")
  }
  //defer { LocalFree(acl) } // TODO is this needed? seems to crash a lot

  var explicitAccess: EXPLICIT_ACCESS_W = EXPLICIT_ACCESS_W(
    grfAccessPermissions: accessPermissions.reduce(0) { $0 | $1.rawValue },
    grfAccessMode: GRANT_ACCESS,
    grfInheritance: DWORD(OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE),
    Trustee: TRUSTEE_W(
      pMultipleTrustee: nil,
      MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
      TrusteeForm: TRUSTEE_IS_SID,
      TrusteeType: TRUSTEE_IS_WELL_KNOWN_GROUP,
      ptstrName: _CASTSID(appContainer.sid.value)
    )
  )

  // Add an entry to the ACL that grants the app container the specified access permissions
  var newAcl: PACL? = nil
  result = withUnsafeMutablePointer(to: &newAcl) {
    SetEntriesInAclW(1, &explicitAccess, acl, $0)
  }
  guard result == ERROR_SUCCESS, let newAcl = newAcl else {
    throw Win32Error("SetEntriesInAclW")
  }
  defer { LocalFree(newAcl) }

  //print("Granting access to '\(path)' for '\(try appContainer.sidString())'")

  // Set the new ACL on the file
  result = path.withCString(encodedAs: UTF16.self) { path in
    SetNamedSecurityInfoW(
      // I dont think this actually mutates the string, at least I hope not
      UnsafeMutablePointer(mutating: path),
      SE_FILE_OBJECT,
      SECURITY_INFORMATION(DACL_SECURITY_INFORMATION),
      nil,
      nil,
      newAcl,
      nil
    )
  }
  guard result == ERROR_SUCCESS else {
    throw Win32Error("SetNamedSecurityInfoW '\(path)'", errorCode: result)
  }
}
public func grantNamedPipeAccess(
  pipe: NamedPipeServer, appContainer: AppContainer, accessPermissions: [AccessPermissions]
)
  throws
{
  guard let handle = pipe.handle else {
    throw SandboxError("Named pipe handle is nil")
  }

  // Read the existing ACL
  var acl: PACL? = nil
  var result = withUnsafeMutablePointer(to: &acl) {
    GetSecurityInfo(
      handle, SE_KERNEL_OBJECT, SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), nil, nil, $0, nil,
      nil)
  }
  guard result == ERROR_SUCCESS, let acl = acl else {
    throw Win32Error("GetNamedSecurityInfoW")
  }
  //defer { LocalFree(acl) } // TODO is this needed? seems to crash a lot

  var explicitAccess: EXPLICIT_ACCESS_W = EXPLICIT_ACCESS_W(
    grfAccessPermissions: accessPermissions.reduce(0) { $0 | $1.rawValue },
    grfAccessMode: GRANT_ACCESS,
    grfInheritance: DWORD(OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE),
    Trustee: TRUSTEE_W(
      pMultipleTrustee: nil,
      MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
      TrusteeForm: TRUSTEE_IS_SID,
      TrusteeType: TRUSTEE_IS_WELL_KNOWN_GROUP,
      ptstrName: _CASTSID(appContainer.sid.value)
    )
  )

  // Add an entry to the ACL that grants the app container the specified access permissions
  var newAcl: PACL? = nil
  result = withUnsafeMutablePointer(to: &newAcl) {
    SetEntriesInAclW(1, &explicitAccess, acl, $0)
  }
  guard result == ERROR_SUCCESS, let newAcl = newAcl else {
    throw Win32Error("SetEntriesInAclW")
  }
  defer { LocalFree(newAcl) }

  // Set the new ACL on the pipe
  result = SetSecurityInfo(
    handle,
    SE_KERNEL_OBJECT,
    SECURITY_INFORMATION(DACL_SECURITY_INFORMATION),
    nil,
    nil,
    newAcl,
    nil
  )
  guard result == ERROR_SUCCESS else {
    throw Win32Error("SetSecurityInfo", errorCode: result)
  }
}
public enum AccessPermissions: DWORD {
  // https://learn.microsoft.com/en-us/windows/win32/secauthz/generic-access-rights
  case genericAll = 0x1000_0000
  case genericExecute = 0x2000_0000
  case genericWrite = 0x4000_0000
  case genericRead = 0x8000_0000
}
