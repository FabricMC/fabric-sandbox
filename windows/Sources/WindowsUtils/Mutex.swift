import WinSDK

class Mutex {
    private let mutex: HANDLE
    
    init() {
        mutex = CreateMutexW(nil, false, nil)
    }
    
    deinit {
        CloseHandle(mutex)
    }
    
    func wait() throws {
        let result = WaitForSingleObject(mutex, INFINITE)
        guard result == WAIT_OBJECT_0 else {
            throw Win32Error("WaitForSingleObject")
        }
    }

    func release() {
        ReleaseMutex(mutex)
    }
}