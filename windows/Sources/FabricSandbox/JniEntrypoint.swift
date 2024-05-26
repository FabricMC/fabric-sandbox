import Jni
import WinSDK

@_cdecl("Java_net_fabricmc_sandbox_Main_nativeEntrypoint")
public func entrypoint(jni: UnsafeMutablePointer<JNIEnv>, clazz: jclass!) {
  do {
    try FabricSandbox().run()
  } catch {
    let runtimeException = jni.pointee.FindClass("java/lang/RuntimeException")!
    let _ = jni.pointee.ThrowNew(runtimeException, "\(error)")
  }
}
