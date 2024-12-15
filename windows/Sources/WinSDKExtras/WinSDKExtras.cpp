#include "WinSDKExtras.h"

#include <VersionHelpers.h>

DWORD _PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES() {
    return PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES;
}

DWORD _PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY() {
    return ProcThreadAttributeValue(ProcThreadAttributeAllApplicationPackagesPolicy, FALSE, TRUE, FALSE);
}

DWORD _MAKELANGID(WORD p, WORD s) {
    return MAKELANGID(p, s);
}

DWORD _SECURITY_MAX_SID_SIZE() {
    return SECURITY_MAX_SID_SIZE;
}

LPPROC_THREAD_ATTRIBUTE_LIST allocateAttributeList(size_t size) {
    return (LPPROC_THREAD_ATTRIBUTE_LIST)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, size);
}

BOOL _IsWindows10OrGreater() {
    return IsWindows10OrGreater();
}

// https://stackoverflow.com/a/22234308
DWORD Win32FromHResult(HRESULT hr) {
    if ((hr & 0xFFFF0000) == MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, 0)) {
        return HRESULT_CODE(hr);
    }
    if (hr == S_OK) {
        return ERROR_SUCCESS;
    }
    // Not a Win32 HRESULT so return a generic error code.
    return ERROR_CAN_NOT_COMPLETE;
}

PSID SidFromAccessAllowedAce(LPVOID ace, DWORD sidStart) {
    return &((ACCESS_ALLOWED_ACE*)ace)->SidStart;
}

PSID SidFromAccessDeniedAce(LPVOID ace, DWORD sidStart) {
    return &((ACCESS_DENIED_ACE*)ace)->SidStart;
}