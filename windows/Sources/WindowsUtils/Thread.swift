import WinSDK

// Thread implimented with win32

open class Thread {
  public var handle: HANDLE? = nil

  public init() throws {
  }

  open func run() {
  }

  var threadProc: LPTHREAD_START_ROUTINE = { (param: LPVOID?) -> DWORD in
    let _self = Unmanaged<Thread>.fromOpaque(param!).takeUnretainedValue()
    _self.run()
    return DWORD(0)
  }

  public func start() {
    let selfPtr = Unmanaged.passUnretained(self).toOpaque()
    let result = CreateThread(nil, 0, threadProc, selfPtr, 0, nil)
    guard let handle = result, handle != INVALID_HANDLE_VALUE else {
      fatalError("CreateThread")
    }
    self.handle = handle
  }

  public func isRunning() -> Bool {
    guard let handle = self.handle else {
      return false
    }
    let result = WaitForSingleObject(handle, 0)
    if result == WAIT_OBJECT_0 {
      return false
    }
    return true
  }

  public func join() throws {
    guard let handle = handle else {
      return
    }
    WaitForSingleObject(handle, INFINITE)
  }
}

struct ThreadError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}
