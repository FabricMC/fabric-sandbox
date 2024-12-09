import WinSDK
import WinSDKExtras
import WindowsUtils

class ProcThreadAttributeList {
  let attributes: [ProcThreadAttribute]
  let attributeList: LPPROC_THREAD_ATTRIBUTE_LIST

  init(attributes: [ProcThreadAttribute]) throws {
    var attributeList = try ProcThreadAttributeList.createAttributeList(attributeCount: attributes.count)

    self.attributes = attributes

    for attribute in self.attributes {
      try attribute.apply(&attributeList)
    }

    self.attributeList = attributeList
  }

  deinit {
    DeleteProcThreadAttributeList(attributeList)
  }

  internal static func createAttributeList(attributeCount: Int) throws
    -> LPPROC_THREAD_ATTRIBUTE_LIST
  {
    var size: UInt64 = 0
    var result = InitializeProcThreadAttributeList(nil, DWORD(attributeCount), 0, &size)
    guard !result, size > 0 else {
      throw Win32Error("InitializeProcThreadAttributeList")
    }

    // Allocate memory for the attribute list
    let list = allocateAttributeList(Int(size))
    guard let list = list else {
      throw Win32Error("AllocateAttributeList")
    }

    // Initialize the attribute list
    result = InitializeProcThreadAttributeList(list, DWORD(attributeCount), 0, &size)

    guard result else {
      throw Win32Error("InitializeProcThreadAttributeList")
    }

    return list
  }
}

protocol ProcThreadAttribute {
  func apply(_ attributeList: inout LPPROC_THREAD_ATTRIBUTE_LIST) throws
}

internal func updateProcThreadAttribute<T>(
  attributeList: inout LPPROC_THREAD_ATTRIBUTE_LIST,
  attribute: DWORD,
  value: UnsafeMutablePointer<T>,
  size: Int
) throws {
  let result = UpdateProcThreadAttribute(
    attributeList,
    0,
    DWORD_PTR(attribute),
    value,
    SIZE_T(size),
    nil,
    nil
  )
  guard result else {
    throw Win32Error("UpdateProcThreadAttribute")
  }
}

class SecurityCapabilitiesProcThreadAttribute: ProcThreadAttribute {
  var securityCapabilities: UnsafeMutablePointer<SECURITY_CAPABILITIES>
  init(container: AppContainer, securityAttributes: UnsafeMutableBufferPointer<SID_AND_ATTRIBUTES>)
  {
    self.securityCapabilities = UnsafeMutablePointer<SECURITY_CAPABILITIES>.allocate(capacity: 1)
    self.securityCapabilities.pointee = SECURITY_CAPABILITIES(
      AppContainerSid: container.sid.value,
      Capabilities: securityAttributes.baseAddress,
      CapabilityCount: DWORD(securityAttributes.count),
      Reserved: 0
    )
  }

  deinit {
    self.securityCapabilities.deallocate()
  }

  func apply(_ attributeList: inout LPPROC_THREAD_ATTRIBUTE_LIST) throws {
    try updateProcThreadAttribute(
      attributeList: &attributeList,
      attribute: _PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES(),
      value: self.securityCapabilities,
      size: MemoryLayout<SECURITY_CAPABILITIES>.size
    )
  }
}

class LessPrivilegedAppContainerProcThreadAttribute: ProcThreadAttribute {
  var enabled: UnsafeMutablePointer<DWORD>

  init() {
    self.enabled = UnsafeMutablePointer<DWORD>.allocate(capacity: 1)
    self.enabled.pointee = 1
  }

  deinit {
    self.enabled.deallocate()
  }

  func apply(_ attributeList: inout LPPROC_THREAD_ATTRIBUTE_LIST) throws {
    try updateProcThreadAttribute(
      attributeList: &attributeList,
      attribute: _PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY(),
      value: self.enabled,
      size: MemoryLayout<DWORD>.size
    )
  }
}
