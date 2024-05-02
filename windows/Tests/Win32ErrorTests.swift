import Testing
import WinSDK

@testable import FabricSandbox
@testable import WindowsUtils

struct Win32ErrorTests {
  @Test func testWin32ErrorSuccess() throws {
    SetLastError(DWORD(ERROR_SUCCESS))
    #expect { try throwWin32Error() } throws: { error in
      let win32Error = error as! Win32Error
      #expect(win32Error.errorDescription == "The operation completed successfully.")
      return true
    }
  }

  @Test func testWin32ErrorAccessDenied() throws {
    SetLastError(DWORD(ERROR_ACCESS_DENIED))
    #expect { try throwWin32Error() } throws: { error in
      let win32Error = error as! Win32Error
      #expect(win32Error.errorDescription == "Access is denied.")
      return true
    }
  }

  internal func throwWin32Error() throws {
    throw Win32Error("Test error")
  }
}
