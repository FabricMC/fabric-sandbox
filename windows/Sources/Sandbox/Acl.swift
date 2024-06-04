import WinSDK
import WinSDKExtras
// Reads the existing ACL for the given path and adds an entry to it that grants the app container the specified access permissions.
import WindowsUtils

public func grantAccess(
  _ file: File, appContainer: AppContainer, accessPermissions: [AccessPermissions]
)
  throws
{
  return try setAccess(file, appContainer: appContainer, accessMode: .grant, accessPermissions: accessPermissions)
}

public func denyAccess(
  _ file: File, appContainer: AppContainer, accessPermissions: [AccessPermissions]
)
  throws
{
  return try setAccess(file, appContainer: appContainer, accessMode: .deny, accessPermissions: accessPermissions)
}

public func setAccess(
  _ file: File, appContainer: AppContainer, accessMode: AccessMode, accessPermissions: [AccessPermissions]
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
  var result = GetNamedSecurityInfoW(
      path.wide, SE_FILE_OBJECT, SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), nil, nil, &acl, nil,
      nil)
  guard result == ERROR_SUCCESS, let acl = acl else {
    throw Win32Error("GetNamedSecurityInfoW")
  }
  
  var explicitAccess: EXPLICIT_ACCESS_W = EXPLICIT_ACCESS_W(
    grfAccessPermissions: accessPermissions.reduce(0) { $0 | $1.rawValue },
    grfAccessMode: accessMode.accessMode,
    grfInheritance: accessMode.inheritanceFlags,
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
  result = SetEntriesInAclW(1, &explicitAccess, acl, &newAcl)
  guard result == ERROR_SUCCESS, var newAcl = newAcl else {
    throw Win32Error("SetEntriesInAclW")
  }
  defer { LocalFree(newAcl) }

  if accessMode == .deny {
    let _ = try removeFirstAceIf(&newAcl) {
      switch $0 {
      case .AccessAllowed(let sid):
        // Remove any existing access allowed ACEs for the app container
        // This likely comes from the parent directory, but we can remove it since inheritance is disabled
        return EqualSid(sid, appContainer.sid.value)
      default:
        return false
      }
    }
  }

  // Set the new ACL on the file
  result = path.withCString(encodedAs: UTF16.self) { path in
    SetNamedSecurityInfoW(
      // I dont think this actually mutates the string, at least I hope not
      UnsafeMutablePointer(mutating: path),
      SE_FILE_OBJECT,
      accessMode.securityInformation,
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

private func removeFirstAceIf(
  _ acl: inout PACL, predicate: (Ace) -> Bool
) throws -> Bool {
  var aclSize: ACL_SIZE_INFORMATION = ACL_SIZE_INFORMATION()
  let success = GetAclInformation(acl, &aclSize, DWORD(MemoryLayout<ACL_SIZE_INFORMATION>.size), AclSizeInformation)
  guard success else {
    throw Win32Error("GetAclInformation")
  }

  var toRemove: DWORD? = nil

  outer: for i: DWORD in 0..<aclSize.AceCount {
    var ace: LPVOID? = nil
    let success = GetAce(acl, DWORD(i), &ace)
    guard success, let ace = ace else {
      throw Win32Error("GetAce")
    }

    let aceHeader = ace.assumingMemoryBound(to: ACE_HEADER.self).pointee

    switch Int32(aceHeader.AceType) {
    case ACCESS_ALLOWED_ACE_TYPE:
      let accessAllowedAce = ace.assumingMemoryBound(to: ACCESS_ALLOWED_ACE.self).pointee
      let sid = SidFromAccessAllowedAce(ace, accessAllowedAce.SidStart)

      if predicate(.AccessAllowed(sid!)) {
        toRemove = i
        break outer
      }
    case ACCESS_DENIED_ACE_TYPE:
      let accessDeniedAce = ace.assumingMemoryBound(to: ACCESS_DENIED_ACE.self).pointee
      let sid = SidFromAccessDeniedAce(ace, accessDeniedAce.SidStart)

      if predicate(.AccessDenied(sid!)) {
        toRemove = i
        break outer
      }
    default:
      break
    }
  }

  if let toRemove = toRemove {
    let success = DeleteAce(acl, toRemove)
    guard success else {
      throw Win32Error("DeleteAce")
    }
    return true
  }

  return false
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
  var result = GetSecurityInfo(
      handle, SE_KERNEL_OBJECT, SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), nil, nil, &acl, nil,
      nil)
  guard result == ERROR_SUCCESS, let acl = acl else {
    throw Win32Error("GetNamedSecurityInfoW")
  }

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
  result = SetEntriesInAclW(1, &explicitAccess, acl, &newAcl)
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

public enum AccessMode {
  case grant
  case deny

  var accessMode: _ACCESS_MODE {
    switch self {
    case .grant: return GRANT_ACCESS
    case .deny: return DENY_ACCESS
    }
  }

  var inheritanceFlags: DWORD {
    switch self {
    case .grant: return DWORD(OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE)
    case .deny: return DWORD(NO_INHERITANCE)
    }
  }

  var securityInformation: SECURITY_INFORMATION {
    switch self {
    case .grant: return SECURITY_INFORMATION(DACL_SECURITY_INFORMATION)
    case .deny: return SECURITY_INFORMATION(UInt32(DACL_SECURITY_INFORMATION) | PROTECTED_DACL_SECURITY_INFORMATION)
    }
  }
}

public enum Ace {
  case AccessAllowed(PSID)
  case AccessDenied(PSID)
}