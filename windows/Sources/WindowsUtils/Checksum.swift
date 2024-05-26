import WinSDK

// Defines from bcrypt.h
private let BCRYPT_MD5_ALGORITHM = "MD5"
private let BCRYPT_SHA1_ALGORITHM = "SHA1"
private let BCRYPT_SHA256_ALGORITHM = "SHA256"
private let BCRYPT_OBJECT_LENGTH = "ObjectLength"
private let BCRYPT_HASH_LENGTH = "HashDigestLength"

public final class Checksum {
    public static func hex(_ str: String, _ algorithm: HashAlgorithm) throws -> String {
        let algorithmProvider = try AlgorithmProvider(algorithm: algorithm)

        var hashObjectSize: DWORD = 0
        var dataLength: DWORD = 0
        var result = BCryptGetProperty(algorithmProvider.handle, BCRYPT_OBJECT_LENGTH.wide, &hashObjectSize, DWORD(MemoryLayout<ULONG>.size), &dataLength, 0)
        guard result == 0 else {
            throw Win32Error("BCryptGetProperty", result: result)
        }

        var hashLength: DWORD = 0
        result = BCryptGetProperty(algorithmProvider.handle, BCRYPT_HASH_LENGTH.wide, &hashLength, DWORD(MemoryLayout<ULONG>.size), &dataLength, 0)
        guard result == 0 else {
            throw Win32Error("BCryptGetProperty", result: result)
        }

        let hash = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(hashLength))
        let hashObject = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(hashObjectSize))
        defer {
            hash.deallocate()
            hashObject.deallocate()
        }

        let hashHandle = try HashHandle(algorithmProvider: algorithmProvider, hashObject: hashObject, hashObjectSize: hashObjectSize)

        // Finally we can hash the data
        result = Array(str.utf8).withUnsafeBytes { ptr in
            let bytes = ptr.bindMemory(to: UInt8.self).baseAddress!
            return BCryptHashData(hashHandle.handle, PBYTE(mutating: bytes), UInt32(ptr.count), 0)
        }
        guard result == 0 else {
            throw Win32Error("BCryptHashData", result: result)
        }

        result = BCryptFinishHash(hashHandle.handle, hash, hashLength, 0)
        guard result == 0 else {
            throw Win32Error("BCryptFinishHash", result: result)
        }

        return toHex(hash, hashLength: Int(hashLength))
    }

    // Convert bytes to a hex string without using String format
    private static func toHex(_ data: UnsafeMutablePointer<UInt8>, hashLength: Int) -> String {
        let hexDigits: [UInt8] = [UInt8]("0123456789abcdef".utf8)
        var hex = [UInt8](repeating: 0, count: hashLength * 2)
        for i in 0..<hashLength {
            let byte = data[i]
            hex[i * 2] = hexDigits[Int(byte / 16)]
            hex[i * 2 + 1] = hexDigits[Int(byte % 16)]
        }
        // Null terminate the string
        hex.append(0)
        return String(cString: hex)
    }
}

public enum HashAlgorithm {
  case md5
  case sha1
  case sha256
}
private class AlgorithmProvider {
    let handle: BCRYPT_ALG_HANDLE

    init(algorithm: HashAlgorithm) throws {
        var handle: BCRYPT_ALG_HANDLE?
        let algorithmIdentifier = AlgorithmProvider.getCNGAlgorithmIdentifier(algorithm)
        let result = BCryptOpenAlgorithmProvider(&handle, algorithmIdentifier.wide, nil, 0)
        guard result == 0, let handle = handle else {
            throw Win32Error("BCryptOpenAlgorithmProvider", result: result)
        }
        self.handle = handle
    }

    deinit {
        BCryptCloseAlgorithmProvider(handle, 0)
    }

    static func getCNGAlgorithmIdentifier(_ algorithm: HashAlgorithm) -> String {
        switch algorithm {
        case .md5:
            return BCRYPT_MD5_ALGORITHM
        case .sha1:
            return BCRYPT_SHA1_ALGORITHM
        case .sha256:
            return BCRYPT_SHA256_ALGORITHM
        }
    }
}

private class HashHandle {
    let handle: BCRYPT_HASH_HANDLE

    init(algorithmProvider: AlgorithmProvider, hashObject: UnsafeMutablePointer<BYTE>, hashObjectSize: DWORD) throws {
        var handle: BCRYPT_HASH_HANDLE?
        let result = BCryptCreateHash(algorithmProvider.handle, &handle, hashObject, hashObjectSize, nil, 0, 0)
        guard result == 0, let handle = handle else {
            throw Win32Error("BCryptCreateHash", result: result)
        }
        self.handle = handle
    }

    deinit {
        BCryptDestroyHash(handle)
    }
}