import WinSDK
import WindowsUtils

class JobObject {
  let handle: HANDLE

  init() {
    self.handle = CreateJobObjectW(nil, nil)
  }

  deinit {
    CloseHandle(handle)
  }

  // Close the child processes when the job object (parent process) is closed
  func killOnJobClose() throws {
    var info = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
    info.BasicLimitInformation.LimitFlags = DWORD(JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE)

    let size = DWORD(MemoryLayout<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>.size)
    guard SetInformationJobObject(handle, JobObjectExtendedLimitInformation, &info, size) else {
      throw Win32Error("SetInformationJobObject failed")
    }
  }

  func assignProcess(_ process: PROCESS_INFORMATION) throws {
    guard AssignProcessToJobObject(handle, process.hProcess) else {
      throw Win32Error("AssignProcessToJobObject failed")
    }
  }
}
