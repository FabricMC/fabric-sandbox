import Jni

extension String {
  // Construct a String from a jstring
  init(_ env: UnsafeMutablePointer<JNIEnv>, jstring: jstring!) {
    var jni = env.pointee
    let chars = jni.GetStringChars(jstring, nil)!
    defer { jni.ReleaseStringChars(jstring, chars) }
    self = String(decodingCString: chars, as: UTF16.self)
  }
}
