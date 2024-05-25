import Jni
import WinSDK

@_cdecl("Java_net_fabricmc_sandbox_Main_nativeEntrypoint")
public func entrypoint(env: UnsafeMutablePointer<JNIEnv>, clazz: jclass!) {
  do {
    try FabricSandbox().run()
  } catch {
    var jni = env.pointee
    let runtimeException = jni.FindClass("java/lang/RuntimeException")!
    let _ = jni.ThrowNew(runtimeException, "\(error)")
  }
}
