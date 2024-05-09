import WinSDK

// A COM RAII helper for the current thread
public class Com {
    public init() {
        CoInitializeEx(nil, 0)
    }
    
    deinit {
        CoUninitialize()
    }
}