import WindowsUtils
import WinSDK

// https://github.com/discord/discord-rpc/blob/master/documentation/hard-mode.md
// https://github.com/discord/discord-rpc/blob/963aa9f3e5ce81a4682c6ca3d136cddda614db33/src/connection_win.cpp#L35C26-L35C52
fileprivate var PIPE_BASE_NAME = "\\\\?\\pipe\\discord-ipc-" // 0-9 suffix

// Grant access to any of the running Discord pipes
public func grantAccessToDiscordPipes(trustee: Trustee) throws {
    for i in 0..<10 {
        let pipe = try? NamedPipeClient(
            pipeName: "\(PIPE_BASE_NAME)\(i)",
            desiredAccess: DWORD(READ_CONTROL | WRITE_DAC), // We only need to open the pipe to set the DACL
            mode: nil
        )
        guard let pipe = pipe else {
            continue
        }

        logger.info("Granting access to Discord named pipe: \(pipe.path)")

        // Remove any existing ACEs for the trustee and then grant full access
        // Ensure we only modify the DACL if the trustee doesn't already have access, to avoid breaking an existing connection
        let hasEntry = try hasAceEntry(pipe, trustee: trustee)
        if !hasEntry {
            try grantAccess(pipe, trustee: trustee, accessPermissions: [.genericAll])
        }
    }
}