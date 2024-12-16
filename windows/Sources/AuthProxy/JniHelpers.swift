import Jni

public typealias JNIEnvPtr = UnsafeMutablePointer<JNIEnv>

extension JNIEnvPtr {
    public func getClass(_ name: String) throws -> jclass {
        let clazz = self.pointee.FindClass(name)
        guard let clazz = clazz else {
            throw JavaError.jni("Failed to find class: \(name)")
        }
        return clazz
    }

    public func checkException() throws {
        if self.pointee.ExceptionCheck() == JNI_TRUE {
            self.pointee.ExceptionDescribe()
            self.pointee.ExceptionClear() // Clear the exception so we can call other JNI functions
            throw JavaError.exception("Java exception")
        }
    }
}

public class JString {
    let jni: UnsafeMutablePointer<JNIEnv>
    let jstr: jstring

    init(_ jni: UnsafeMutablePointer<JNIEnv>, string: String) throws {
        let jstr = jni.pointee.NewStringUTF(string)
        guard let jstr = jstr else {
            throw JavaError.jni("Failed to create string")
        }

        self.jni = jni
        self.jstr = jstr
    }

    deinit {
        jstr.withMemoryRebound(to: jobject.self, capacity: 1) {
            jni.pointee.DeleteLocalRef($0.pointee)
        }
    }
}

public enum JavaError: Error {
    case exception(String)
    case jni(String)
}