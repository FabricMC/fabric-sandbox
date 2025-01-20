import Jni

public class AuthProxy {
    private let jni: JNIEnvPtr
    private let claszz: jclass
    private let object: jobject

    private init(jni: JNIEnvPtr, claszz: jclass, object: jobject) {
        self.jni = jni
        self.claszz = claszz
        self.object = object
    }

    deinit {
        try? close()
        claszz.withMemoryRebound(to: jobject.self, capacity: 1) {
            jni.pointee.DeleteLocalRef($0.pointee)
        }
    }

    // public static AuthProxy create(int port, String realAccessToken, String sandboxToken) throws IOException {
    public static func create(_ jni: JNIEnvPtr, port: Int32, realAccessToken: String, sandboxToken: String) throws -> AuthProxy {
        let clazz = try jni.getClass("net/fabricmc/sandbox/authproxy/AuthProxy")

        let method = jni.pointee.GetStaticMethodID(clazz, "create", "(ILjava/lang/String;Ljava/lang/String;)Lnet/fabricmc/sandbox/authproxy/AuthProxy;")
        guard let method = method else {
            throw JavaError.jni("Failed to find method")
        }

        let realAccessToken = try JString(jni, string: realAccessToken)
        let sandboxToken = try JString(jni, string: sandboxToken)

        let object = withVaList([port, realAccessToken.jstr, sandboxToken.jstr]) {
            jni.pointee.CallStaticObjectMethodV(clazz, method, $0)
        }
        guard let object = object else {
            throw JavaError.jni("Failed to create object")
        }
        try jni.checkException()

        return AuthProxy(jni: jni, claszz: clazz, object: object)
    }

    // String[] getArguments()
    public func getArguments() throws -> [String] {
        let method = jni.pointee.GetMethodID(claszz, "getArguments", "()[Ljava/lang/String;")
        guard let method = method else {
            throw JavaError.jni("Failed to find method")
        }

        let array = withVaList([]) {
            jni.pointee.CallObjectMethodV(object, method, $0)
        }
        guard let array = array else {
            throw JavaError.jni("Failed to get return value")
        }

        let length = array.withMemoryRebound(to: _jarray.self, capacity: 1) { array in
            jni.pointee.GetArrayLength(array)
        }

        return try array.withMemoryRebound(to: jobjectArray.self, capacity: 1) { array in
            try (0..<length).map { index in
                let element = array.withMemoryRebound(to: _jobjectArray.self, capacity: 1) { array in
                    jni.pointee.GetObjectArrayElement(array, index)
                }
                guard let element = element else {
                    throw JavaError.jni("Failed to get array element")
                }

                return try element.withMemoryRebound(to: _jstring.self, capacity: 1) { string in
                    let cString = jni.pointee.GetStringUTFChars(string, nil)
                    guard let cString = cString else {
                        throw JavaError.jni("Failed to get string")
                    }
                    defer {
                        jni.pointee.ReleaseStringUTFChars(string, cString)
                    }

                    return String(cString: cString)
                }
            }
        }
    }

    func close() throws {
        let method = jni.pointee.GetMethodID(claszz, "close", "()V")
        guard let method = method else {
            throw JavaError.jni("Failed to find method")
        }

        withVaList([]) {
            jni.pointee.CallVoidMethodV(object, method, $0)
        }
        try jni.checkException()
    }
}