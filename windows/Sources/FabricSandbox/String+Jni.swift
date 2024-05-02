import Jni

extension String {
  // Construct a String from a jstring
  init(_ env: UnsafeMutablePointer<JNIEnv?>!, jstring: jstring!) {
    let jni = env.pointee!.pointee
    let chars = jni.GetStringChars(env, jstring, nil)!
    defer { jni.ReleaseStringChars(env, jstring, chars) }
    self = String(decodingCString: chars, as: UTF16.self)
  }
}
