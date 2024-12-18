import WinSDK

public func generateUUID() throws -> String {
    var uuid = UUID()
    var result = UuidCreate(&uuid)
    guard result == RPC_S_OK else {
        throw Win32Error("UuidCreate")
    }

    var rpcStr: RPC_CSTR?
    result = UuidToStringA(&uuid, &rpcStr)
    guard result == RPC_S_OK else {
        throw Win32Error("UuidToStringA")
    }
    defer {
        RpcStringFreeA(&rpcStr)
    }

    return String(cString: rpcStr!)
}