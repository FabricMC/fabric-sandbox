import WinSDK
import WinSDKExtras

public func grantAccess(
  _ object: SecurityObject, trustee: Trustee, accessPermissions: [AccessPermissions]
)
  throws
{
  return try setAccess(object, trustee: trustee, accessMode: .grant, accessPermissions: accessPermissions)
}

public func denyAccess(
  _ object: SecurityObject, trustee: Trustee, accessPermissions: [AccessPermissions]
)
  throws
{
  return try setAccess(object, trustee: trustee, accessMode: .deny, accessPermissions: accessPermissions)
}

public func setAccess(
  _ object: SecurityObject, trustee: Trustee, accessMode: AccessMode, accessPermissions: [AccessPermissions]
)
  throws
{
  let acl = try object.getACL()
  
  var explicitAccess = EXPLICIT_ACCESS_W(
    grfAccessPermissions: accessPermissions.reduce(0) { $0 | $1.rawValue },
    grfAccessMode: accessMode.accessMode,
    grfInheritance: accessMode.inheritanceFlags,
    Trustee: trustee.trustee
  )

  // Add an entry to the ACL that grants the app container the specified access permissions
  var newAcl: PACL? = nil
  let result = SetEntriesInAclW(1, &explicitAccess, acl, &newAcl)
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
        return EqualSid(sid, trustee.sid.value)
      default:
        return false
      }
    }
  }

  try object.setACL(acl: newAcl, accessMode: accessMode)
}

// Removes all specified access permissions for the trustee
public func clearAccess(_ object: SecurityObject, trustee: Trustee) throws {
  var acl = try object.getACL()

  while true {
    let removed = try removeFirstAceIf(&acl) {
      switch $0 {
      case .AccessAllowed(let sid), .AccessDenied(let sid):
        return EqualSid(sid, trustee.sid.value)
      }
    }

    if !removed {
      break
    }
  }

  try object.setACL(acl: acl, accessMode: .grant)
}

// Do not use this as a security check
public func hasAceEntry(_ object: SecurityObject, trustee: Trustee) throws -> Bool {
  let acl = try object.getACL()
  let sid = trustee.sid.value

  var aclSize = ACL_SIZE_INFORMATION()
  let success = GetAclInformation(acl, &aclSize, DWORD(MemoryLayout<ACL_SIZE_INFORMATION>.size), AclSizeInformation)
  guard success else {
    throw Win32Error("GetAclInformation")
  }

  for i: DWORD in 0..<aclSize.AceCount {
    var ace: LPVOID? = nil
    let success = GetAce(acl, DWORD(i), &ace)
    guard success, let ace = ace else {
      throw Win32Error("GetAce")
    }

    let aceHeader = ace.assumingMemoryBound(to: ACE_HEADER.self).pointee

    switch Int32(aceHeader.AceType) {
    case ACCESS_ALLOWED_ACE_TYPE:
      let accessAllowedAce = ace.assumingMemoryBound(to: ACCESS_ALLOWED_ACE.self).pointee
      let aceSid = SidFromAccessAllowedAce(ace, accessAllowedAce.SidStart)

      if let aceSid = aceSid, EqualSid(aceSid, sid) {
        return true
      }
    case ACCESS_DENIED_ACE_TYPE:
      let accessDeniedAce = ace.assumingMemoryBound(to: ACCESS_DENIED_ACE.self).pointee
      let aceSid = SidFromAccessDeniedAce(ace, accessDeniedAce.SidStart)

      if let aceSid = aceSid, EqualSid(aceSid, sid) {
        return true
      }
    default:
      break
    }
  }

  return false
}

public func getStringSecurityDescriptor(_ object: SecurityObject) throws -> String {
  let acl = try object.getACL()

  var securityDescriptor = SECURITY_DESCRIPTOR()
  guard InitializeSecurityDescriptor(&securityDescriptor, DWORD(SECURITY_DESCRIPTOR_REVISION)) else {
    throw Win32Error("InitializeSecurityDescriptor")
  }

  guard SetSecurityDescriptorDacl(&securityDescriptor, true, acl, false) else {
    throw Win32Error("SetSecurityDescriptorDacl")
  }

  return try getStringSecurityDescriptor(&securityDescriptor)
}

public func getStringSecurityDescriptor(_ securityDescriptor: inout SECURITY_DESCRIPTOR) throws -> String {
  var stringSecurityDescriptor: LPWSTR? = nil
  let result = ConvertSecurityDescriptorToStringSecurityDescriptorW(
    &securityDescriptor, DWORD(SDDL_REVISION_1), SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), &stringSecurityDescriptor, nil)
  guard result, let stringSecurityDescriptor = stringSecurityDescriptor else {
    throw Win32Error("ConvertSecurityDescriptorToStringSecurityDescriptorW")
  }

  return String(decodingCString: stringSecurityDescriptor, as: UTF16.self)
}

public func createACLWithTrustees(_ trustees: [Trustee], accessMode: AccessMode = .grant, accessPermissions: [AccessPermissions] = [.genericAll]) throws -> PACL {
  var explicitAccess = trustees.map { trustee in
    return EXPLICIT_ACCESS_W(
      grfAccessPermissions: accessPermissions.reduce(0) { $0 | $1.rawValue },
      grfAccessMode: accessMode.accessMode,
      grfInheritance: accessMode.inheritanceFlags,
      Trustee: trustee.trustee
    )
  }

  var acl: PACL? = nil
  let result = SetEntriesInAclW(ULONG(explicitAccess.count), &explicitAccess, nil, &acl)
  guard result == ERROR_SUCCESS, let acl = acl else {
    throw Win32Error("SetEntriesInAclW")
  }

  return acl
}

public func createSelfRelativeSecurityDescriptor(_ securityDescriptor: inout SECURITY_DESCRIPTOR) throws -> UnsafeMutablePointer<SECURITY_DESCRIPTOR> {
  var relativeSize = DWORD(0)
    guard !MakeSelfRelativeSD(&securityDescriptor, nil, &relativeSize)
              && GetLastError() == ERROR_INSUFFICIENT_BUFFER else {
      throw Win32Error("MakeSelfRelativeSD")
    }

    let relativeDescriptor = UnsafeMutableRawPointer.allocate(
      byteCount: Int(relativeSize),
      alignment: MemoryLayout<SECURITY_DESCRIPTOR>.alignment
    ).assumingMemoryBound(to: SECURITY_DESCRIPTOR.self)

    guard MakeSelfRelativeSD(&securityDescriptor, relativeDescriptor, &relativeSize) else {
      relativeDescriptor.deallocate()
      throw Win32Error("MakeSelfRelativeSD")
    }

    return relativeDescriptor
}

// Remove the first ACE that matches the predicate, returning whether an ACE was removed
private func removeFirstAceIf(
  _ acl: inout PACL, predicate: (Ace) -> Bool
) throws -> Bool {
  var aclSize = ACL_SIZE_INFORMATION()
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

fileprivate func getTokenUserSid() throws -> Sid {
  var processHandle: HANDLE? = nil
  let result = OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &processHandle)
  guard result, processHandle != INVALID_HANDLE_VALUE, let processHandle = processHandle else {
    throw Win32Error("OpenProcessToken")
  }

  let tokenUser = try getTokenInformation(of: TOKEN_USER.self, token: processHandle, tokenClass: TokenUser)
  defer {
    tokenUser.deallocate()
  }

  return try Sid(copy: tokenUser.pointee.User.Sid)
}

// Based on: https://github.com/apple/swift-system/blob/61a2af5e8b55535be68c35efebb3d398de512352/Sources/System/Internals/WindowsSyscallAdapters.swift#L372
fileprivate func getTokenInformation<T>(of: T.Type, token: HANDLE, tokenClass: TOKEN_INFORMATION_CLASS) throws -> UnsafePointer<T> {
  var size = DWORD(1024)
  for _ in 0..<2 {
    let buffer = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size),
      alignment: MemoryLayout<T>.alignment
    )

    if GetTokenInformation(token, tokenClass, buffer, size, &size) {
      return UnsafePointer(buffer.assumingMemoryBound(to: T.self))
    }

    buffer.deallocate()
  }
  throw Win32Error("GetTokenInformation")
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

public protocol Trustee {
  var sid: Sid { get }
  var trustee: TRUSTEE_W { get }
}

public class WellKnownTrustee: Trustee {
    public let sid: Sid
    public let trustee: TRUSTEE_W

    public init(sid: String) throws {
        self.sid = try Sid(sid)
        self.trustee = TRUSTEE_W(
            pMultipleTrustee: nil,
            MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
            TrusteeForm: TRUSTEE_IS_SID,
            TrusteeType: TRUSTEE_IS_WELL_KNOWN_GROUP,
            ptstrName: self.sid.ptstrName
        )
    }
}

// A trustee that represents the current process/user
public class TokenUserTrustee: Trustee {
  public let sid: Sid
  public let trustee: TRUSTEE_W

  public init() throws {
    let sid = try getTokenUserSid()
    self.sid = sid
    self.trustee = TRUSTEE_W(
      pMultipleTrustee: nil,
      MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
      TrusteeForm: TRUSTEE_IS_SID,
      TrusteeType: TRUSTEE_IS_USER,
      ptstrName: sid.ptstrName
    )
  }
}

public protocol SecurityObject {
  func getACL() throws -> PACL
  func setACL(acl: PACL, accessMode: AccessMode) throws
}

extension File: SecurityObject {
  public func getACL() throws -> PACL {
    let path = self.path()
    guard GetFileAttributesW(path.wide) != INVALID_FILE_ATTRIBUTES else {
      throw Win32Error("Path does not exist: '\(path)'", errorCode: DWORD(ERROR_FILE_NOT_FOUND))
    }

    var acl: PACL? = nil
    let result = GetNamedSecurityInfoW(
      path.wide, SE_FILE_OBJECT, SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), nil, nil, &acl, nil, nil)

    guard result == ERROR_SUCCESS, let acl = acl else {
      throw Win32Error("GetNamedSecurityInfoW(\(path))", errorCode: result)
    }
    return acl
  }

  public func setACL(acl: PACL, accessMode: AccessMode) throws {
    let result = self.path().withCString(encodedAs: UTF16.self) {
      SetNamedSecurityInfoW(
        UnsafeMutablePointer(mutating: $0), SE_FILE_OBJECT, accessMode.securityInformation, nil, nil, acl, nil)
    }

    guard result == ERROR_SUCCESS else {
      throw Win32Error("SetNamedSecurityInfoW(\(self.path()))", errorCode: result)
    }
  }
}

extension NamedPipeClient: SecurityObject {
  public func getACL() throws -> PACL {
    var acl: PACL? = nil
    let result = GetSecurityInfo(
      self.pipe, SE_KERNEL_OBJECT, SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), nil, nil, &acl, nil, nil)

    guard result == ERROR_SUCCESS, let acl = acl else {
      throw Win32Error("GetSecurityInfo(\(self.path))", errorCode: result)
    }
    return acl
  }

  public func setACL(acl: PACL, accessMode: AccessMode) throws {
    let result = SetSecurityInfo(
      self.pipe, SE_KERNEL_OBJECT, SECURITY_INFORMATION(DACL_SECURITY_INFORMATION), nil, nil, acl, nil)

    guard result == ERROR_SUCCESS else {
      throw Win32Error("SetSecurityInfo(\(self.path))", errorCode: result)
    }
  }
}