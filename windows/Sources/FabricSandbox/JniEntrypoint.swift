import Jni
import WinSDK

@_cdecl("Java_net_fabricmc_sandbox_Main_nativeEntrypoint")
func entrypoint(env: UnsafeMutablePointer<JNIEnv?>!, clazz: jclass!) {
  do {
    try FabricSandbox().run()
  } catch {
    let jni = env.pointee!.pointee
    let runtimeException = jni.FindClass(env, "java/lang/RuntimeException")!
    let _ = jni.ThrowNew(env, runtimeException, "\(error)")
  }
}
