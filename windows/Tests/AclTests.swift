import Testing
import WinSDK
import WindowsUtils

struct AclTests {
    @Test func testAcl() throws {
    let tempDir = try createTempDir()
    defer {
      try! tempDir.delete()
    }

    let trustee = try WellKnownTrustee(sid: "S-1-5-21-3456789012-2345678901-1234567890-1234")
    let sid = trustee.sid.description

    var sddl = try getStringSecurityDescriptor(tempDir)
    #expect(!sddl.contains(";\(sid)"))
    #expect(!(try hasAceEntry(tempDir, trustee: trustee)))

    try grantAccess(tempDir, trustee: trustee, accessPermissions: [.genericAll])
    sddl = try getStringSecurityDescriptor(tempDir)
    // Allow full access
    #expect(sddl.contains("A;;FA;;;\(sid)"))
    #expect(try hasAceEntry(tempDir, trustee: trustee))

    try clearAccess(tempDir, trustee: trustee)
    sddl = try getStringSecurityDescriptor(tempDir)
    #expect(!sddl.contains(";\(sid)"))
    #expect(!(try hasAceEntry(tempDir, trustee: trustee)))

    try denyAccess(tempDir, trustee: trustee, accessPermissions: [.genericExecute])
    sddl = try getStringSecurityDescriptor(tempDir)
    // Deny execute
    #expect(sddl.contains("D;;FX;;;\(sid)"))
    #expect(try hasAceEntry(tempDir, trustee: trustee))

    // Test that we can remove mutlipe ACEs
    try grantAccess(tempDir, trustee: trustee, accessPermissions: [.genericRead])
    try clearAccess(tempDir, trustee: trustee)
    sddl = try getStringSecurityDescriptor(tempDir)
    #expect(!sddl.contains(";\(sid)"))
    #expect(!(try hasAceEntry(tempDir, trustee: trustee)))
  }
}