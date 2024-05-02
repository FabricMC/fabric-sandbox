import WinSDK
import WinSDKExtras
import WindowsUtils

class ProcThreadAttributeList {
  let ptr: LPPROC_THREAD_ATTRIBUTE_LIST

  init(attributes: [ProcThreadAttribute]) throws {
    ptr = try ProcThreadAttributeList.createAttributeList(attributeCount: attributes.count)

    for attribute in attributes {
      try attribute.apply(ptr)
    }
  }

  deinit {
    DeleteProcThreadAttributeList(ptr)
  }

  internal static func createAttributeList(attributeCount: Int) throws
    -> LPPROC_THREAD_ATTRIBUTE_LIST
  {
    var size: UInt64 = 0
    var result = withUnsafeMutablePointer(to: &size) {
      InitializeProcThreadAttributeList(nil, DWORD(attributeCount), 0, $0)
    }
    guard !result, size > 0 else {
      throw Win32Error("InitializeProcThreadAttributeList")
    }

    // Allocate memory for the attribute list
    let list = allocateAttributeList(Int(size))
    guard let list = list else {
      throw Win32Error("AllocateAttributeList")
    }

    // Initialize the attribute list
    result = withUnsafeMutablePointer(to: &size) { size in
      InitializeProcThreadAttributeList(list, DWORD(attributeCount), 0, size)
    }

    guard result else {
      throw Win32Error("InitializeProcThreadAttributeList")
    }

    return list
  }
}

protocol ProcThreadAttribute {
  func apply(_ ptr: LPPROC_THREAD_ATTRIBUTE_LIST) throws
}

internal func updateProcThreadAttribute<T>(
  ptr: LPPROC_THREAD_ATTRIBUTE_LIST,
  attribute: DWORD,
  value: inout T,
  size: Int
) throws {
  let result = withUnsafeMutablePointer(to: &value) {
    UpdateProcThreadAttribute(
      ptr,
      0,
      DWORD_PTR(attribute),
      $0,
      SIZE_T(size),
      nil,
      nil
    )
  }
  guard result else {
    throw Win32Error("UpdateProcThreadAttribute")
  }
}

class SecurityCapabilitiesProcThreadAttribute: ProcThreadAttribute {
  var securityCapabilities: SECURITY_CAPABILITIES
  init(container: AppContainer, securityAttributes: UnsafeMutableBufferPointer<SID_AND_ATTRIBUTES>)
  {
    self.securityCapabilities = SECURITY_CAPABILITIES(
      AppContainerSid: container.sid.value,
      Capabilities: securityAttributes.baseAddress,
      CapabilityCount: DWORD(securityAttributes.count),
      Reserved: 0
    )
  }

  func apply(_ ptr: LPPROC_THREAD_ATTRIBUTE_LIST) throws {
    try updateProcThreadAttribute(
      ptr: ptr,
      attribute: _PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES(),
      value: &self.securityCapabilities,
      size: MemoryLayout<SECURITY_CAPABILITIES>.size
    )
  }
}

class LessPrivilegedAppContainerProcThreadAttribute: ProcThreadAttribute {
  func apply(_ ptr: LPPROC_THREAD_ATTRIBUTE_LIST) throws {
    var enabled: DWORD = 1

    try updateProcThreadAttribute(
      ptr: ptr,
      attribute: _PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY(),
      value: &enabled,
      size: MemoryLayout<DWORD>.size
    )
  }
}
