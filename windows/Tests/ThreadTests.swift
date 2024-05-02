import Testing
import WinSDK
import WindowsUtils

struct ThreadTests {
  @Test func runThread() throws {
    let thread = try TestThread()
    thread.start()
    #expect(thread.isRunning())
    try thread.join()
    #expect(thread.ran)
  }
}

class TestThread: Thread {
  var ran = false

  override init() throws {
    try super.init()
  }

  override func run() {
    Sleep(DWORD(100))
    ran = true
  }
}
